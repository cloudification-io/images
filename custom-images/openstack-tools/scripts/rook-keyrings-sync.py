# Copyright (c) 2024 Cloudification GmbH.
# All Rights Reserved.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.
#
# How this script works:
# Update Ceph monitor IPs for Openstack apps:
#     1. Get current Ceph monitor IPs (into `mon_host`) and prepare ceph.conf
#     2. Compare with existing Openstack config and update with new IPs
#     3. Schedule appropriate applications for restart

# Update\rotate Ceph client keyrings:
#     1. Fetch new client keyring from rook namespace
#     2. Update clientkeyring in openstack namespace
#     3. Schedule updated apps for restart

# Restart scheduled for restart deployments\pods:
#     - * Before restarting libvirt inject new keyring into virsh to avoid VM
#         restarts
import base64
import difflib
import json
import logging
import os
import re
import subprocess
import shlex
import shutil
import sys
import tempfile
import argparse
import yaml

ROOK_CEPH_NAMESPACE = 'rook-ceph'
OPENSTACK_NAMESPACE = 'openstack'
OPENSTACK_CEPH_ETC_CM = 'ceph-etc'
DEFAULT_CONFIG_PATH = '/opt/openstack-tools/config.yaml'

LOG = logging.getLogger(__name__)


class CommandError(Exception):
    pass


class NotFound(CommandError):
    pass

class Updater():

    def __init__(self, config_path=None):
        self._kctl = shutil.which('kubectl')
        self._restart_queue = []
        self._keyrings_cache = {}
        self._config = self._load_config(config_path or DEFAULT_CONFIG_PATH)
        
    def _load_config(self, config_path):
        """Load configuration from YAML file."""
        if not os.path.exists(config_path):
            LOG.error(f"Configuration file not found: {config_path}")
            sys.exit(1)
            
        try:
            with open(config_path, 'r') as f:
                config = yaml.safe_load(f)
            LOG.debug(f"Loaded configuration from {config_path}")
            return config
        except Exception as e:
            LOG.error(f"Failed to load configuration: {str(e)}")
            sys.exit(1)

    def _run_cmd(self, command: str) -> str:
        LOG.debug(f'Exec command: {command}')
        process = subprocess.Popen(
            shlex.split(command),
            cwd='/',
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        out, err = process.communicate()
        if process.returncode != 0:
            err_str = err.decode('utf-8')
            if 'NotFound' in err_str:
                raise NotFound(err_str)
            else:
                raise CommandError(err_str)
        return out.decode('utf-8').rstrip()

    def _diff(self, current: str, candidate: str) -> str:
        return ''.join(difflib.context_diff(
            current.splitlines(keepends=True),
            candidate.splitlines(keepends=True),
            fromfile='existing', tofile='candidate'))

    def _b64enc(self, data: str) -> str:
        return base64.b64encode(data.encode('utf-8')).decode('utf-8')

    def _b64dec(self, data: str) -> str:
        return base64.b64decode(data.encode('utf-8')).decode('utf-8')

    def _get_keyring_from_admin_secret(self, config: str) -> str:
        return re.findall(r'key\s+=\s+(.*)$', config, re.M)[0]

    def _get_obj(self, namespace: str, obj: str, name: str) -> dict:
        return json.loads(self._run_cmd(f'{self._kctl} -n {namespace} get {obj} {name} -o json'))

    def _exec_obj(self, namespace: str, name: str, command: str) -> str:
        return self._run_cmd(f'{self._kctl} -n {namespace} exec {name} -- {command}')

    def _restart_obj(self, namespace: str, name: str):
        LOG.debug(self._run_cmd(f'{self._kctl} -n {namespace} rollout restart {name}'))
        LOG.debug(self._run_cmd(f'{self._kctl} -n {namespace} rollout status {name} --timeout=1h'))

    def _sync_obj(self, namespace: str, obj: str, name: str, key: str, data: str, replace: bool):
        with tempfile.NamedTemporaryFile() as fc:
            fc.write(data.encode('utf-8'))
            fc.seek(0)
            create_cmd = None
            if obj == 'configmap':
                create_cmd = f'{self._kctl} -n {namespace} create configmap {name} --from-file={key}={fc.name}'
            elif obj == 'secret':
                create_cmd = f'{self._kctl} -n {namespace} create secret generic {name} --from-file={key}={fc.name}'
            if replace:
                create_cmd += ' -o yaml --dry-run=client'
            obj_yaml = self._run_cmd(create_cmd)
            if replace:
                with tempfile.NamedTemporaryFile() as ft:
                    ft.write(obj_yaml.encode('utf-8'))
                    ft.seek(0)
                    self._run_cmd(f'{self._kctl} replace -f {ft.name}')

    def _sync_ceph_config(self):
        mon_cfg = self._get_obj(ROOK_CEPH_NAMESPACE, 'configmap', 'rook-ceph-mon-endpoints')
        monitors = re.sub('[a-z]+=', '', mon_cfg['data']['data'])
        LOG.debug(f'Found Ceph monitors: {monitors}')
        cur_ceph_config = f'[global]\nmon_host = {monitors}\n'
        cluster_ceph_config = ''
        config_exists = True
        try:
            cluster_ceph_config = self._get_obj(OPENSTACK_NAMESPACE, 'configmap', OPENSTACK_CEPH_ETC_CM)
            cluster_ceph_config = cluster_ceph_config['data']['ceph.conf']
        except NotFound:
            LOG.debug(f'Ceph config in configmap {OPENSTACK_CEPH_ETC_CM} does not exist')
            config_exists = False
        if cur_ceph_config != cluster_ceph_config:
            LOG.info(f'Configmap {OPENSTACK_CEPH_ETC_CM} was changed, updating')
            LOG.debug(f'In configmap {OPENSTACK_CEPH_ETC_CM} section ceph.conf was changed, '
                    f'diff:\n{self._diff(cluster_ceph_config, cur_ceph_config)}')
            self._sync_obj(OPENSTACK_NAMESPACE, 'configmap', OPENSTACK_CEPH_ETC_CM, 'ceph.conf',
                        cur_ceph_config, config_exists)
            # Use the config instead of hardcoded values
            if 'ceph_mon_users' in self._config:
                self._restart_queue.extend(self._config['ceph_mon_users'])
            else:
                LOG.warning("No ceph_mon_users defined in config, nothing to restart")
                self._restart_queue.extend([])
        else:
            LOG.debug(f'Configmap {OPENSTACK_CEPH_ETC_CM} was not changed')

    def _sync_keyring(self, source_secret_name: str, target_secret_name: str, source_secret_key: str,
                      dependencies: list, admin_keyring: bool=False, target_secret_key: str='key'):
        LOG.info(f'Sync {"admin" if admin_keyring else "user"} keyring from secret {source_secret_name} '
                 f'({ROOK_CEPH_NAMESPACE}) with keyring in secret'
                 f' {target_secret_name} ({OPENSTACK_NAMESPACE}) and check dependencies: {dependencies}')
        src_secret = self._get_obj(ROOK_CEPH_NAMESPACE, 'secret', source_secret_name)
        src_keyring = self._b64dec(src_secret['data'][source_secret_key])
        if admin_keyring:
            src_keyring = self._get_keyring_from_admin_secret(src_keyring)
        src_keyring = src_keyring.strip()
        self._keyrings_cache[source_secret_name] = src_keyring
        target_secret = ''
        secret_exists = True
        try:
            target_secret = self._get_obj(OPENSTACK_NAMESPACE, 'secret', target_secret_name)
            target_secret = self._b64dec(target_secret['data'][target_secret_key]).strip()
        except NotFound:
            LOG.debug(f'Secret {target_secret_name} not found in namespace {OPENSTACK_CEPH_ETC_CM}')
            secret_exists = False
        # sync secret if it does not exist or was changed
        if not secret_exists or src_keyring != target_secret:
            LOG.info(f'Secret {target_secret_name} was changed, updating')
            self._sync_obj(OPENSTACK_NAMESPACE, 'secret', target_secret_name, target_secret_key,
                           src_keyring, secret_exists)
            self._restart_queue.extend(dependencies)
        else:
            LOG.debug(f'Secret {target_secret_name} was not changed')
        # check if secret inside containers was not updated
        for dep in dependencies:
            try:
                pod_keyring = self._exec_obj(OPENSTACK_NAMESPACE, dep, 'cat /tmp/client-keyring')
                if pod_keyring != src_keyring and dep not in self._restart_queue:
                    LOG.debug(f'Keyring inside pod of {dep} is incorrect, schedule restart')
                    self._restart_queue.append(dep)
            except:
                LOG.warning(f'Consumer {dep} for secret {target_secret_name} not found')

    def _update_libvirt_secret(self):
        LOG.info('Start updating secrets inside libvirt PODs')
        cinder_secret = self._keyrings_cache['rook-ceph-client-cinder']
        pods = self._run_cmd(f'{self._kctl} -n {OPENSTACK_NAMESPACE} get pod'
                             ' -l application=libvirt -l component=libvirt --no-headers -o name')
        for pod in pods.splitlines():
            cinder_uuid_env = self._run_cmd(f'{self._kctl} -n {OPENSTACK_NAMESPACE} exec {pod} -c libvirt -- '
                                            'bash -c "env | grep LIBVIRT_CEPH_CINDER_SECRET_UUID"')
            cinder_uuid = cinder_uuid_env.split('=')[1]
            secret_in_pod = self._run_cmd(f'{self._kctl} -n {OPENSTACK_NAMESPACE} exec {pod} -c libvirt -- '
                                          f'virsh secret-get-value {cinder_uuid}')
            if secret_in_pod != cinder_secret:
                LOG.debug(f'Updating Cinder secret {cinder_uuid} in libvert POD {pod}')
                self._run_cmd(f'{self._kctl} -n {OPENSTACK_NAMESPACE} exec {pod} -c libvirt -- '
                              f'virsh secret-set-value --secret {cinder_uuid} --base64 {cinder_secret}')
            else:
                LOG.debug(f'Cinder secret inside POD {pod} is correct')

    def _restart_services(self):
        # Normalize resource types using regex
        normalized_queue = []
        for dep in self._restart_queue:
            # Normalize common abbreviations
            normalized_dep = re.sub(r'^ds/', 'daemonset/', dep)
            normalized_dep = re.sub(r'^deploy/', 'deployment/', normalized_dep)
            normalized_queue.append(normalized_dep)
        
        # Deduplicate by converting to set and back to list
        unique_queue = list(set(normalized_queue))
        
        LOG.debug(f"Normalized and deduplicated restart queue: {unique_queue}")
        
        # Restart the normalized resources
        for dep in unique_queue:
            if 'libvirt' in dep:
                self._update_libvirt_secret()
                continue
            LOG.info(f'Restart {dep} in {OPENSTACK_NAMESPACE} namespace')
            self._restart_obj(OPENSTACK_NAMESPACE, dep)

    def sync_creds(self):
        self._sync_ceph_config()
        
        # Process keyrings from config
        if 'keyrings' not in self._config:
            LOG.warning("No keyrings defined in config, skipping keyring sync")
            return
            
        for keyring in self._config['keyrings']:
            name = keyring.get('name', '')
            source_secret = keyring.get('source_secret')
            target_secret = keyring.get('target_secret')
            source_key = keyring.get('source_key')
            dependencies = keyring.get('dependencies', [])
            admin_keyring = keyring.get('admin_keyring', False)
            target_key = keyring.get('target_key', 'key')
            
            if not all([source_secret, target_secret, source_key]):
                LOG.error(f"Skipping incomplete keyring config for {name}")
                sys.exit(1)

            LOG.info(f"Processing keyring {name}")
            self._sync_keyring(
                source_secret, 
                target_secret, 
                source_key,
                dependencies, 
                admin_keyring=admin_keyring, 
                target_secret_key=target_key
            )
        
        LOG.debug(f'Services were scheduled for restart: {self._restart_queue}')
        self._restart_services()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Sync Ceph credentials for OpenStack.')
    parser.add_argument('--config', '-c', help='Path to config file', default=DEFAULT_CONFIG_PATH)
    parser.add_argument('--debug', '-d', action='store_true', help='Enable debug logging')
    args = parser.parse_args()
    
    # set logging
    LOG.setLevel(logging.DEBUG)
    handler = logging.StreamHandler(sys.stdout)
    handler.setLevel(logging.DEBUG)
    formatter = logging.Formatter('%(asctime)s [%(levelname).3s] %(message)s')
    handler.setFormatter(formatter)
    LOG.addHandler(handler)

    # run credentials updater
    updater = Updater(args.config)
    updater.sync_creds()
