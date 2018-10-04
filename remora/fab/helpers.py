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

import glob
import os
import tempfile
import time
import yaml

from fabric.api import env
from fabric.api import local
from fabric.api import run
from fabric.api import task
from fabric.network import parse_host_string

from remora.common import utils
from remora.fab import constants


def remote_temp_dir(target):
    return os.path.join(env['configs']['temp_dir'], target)


def recreate_remote_temp_dir(target):
    temp_path = remote_temp_dir(target)
    run("rm -rf {0}".format(temp_path))
    run("mkdir -p {0}".format(temp_path))


def merge_dicts(dict1, dict2):
    """Recursively merges dict2 into dict1"""
    if not isinstance(dict1, dict) or not isinstance(dict2, dict):
        return dict1
    for k in dict2:
        if k in dict1:
            dict1[k] = merge_dicts(dict1[k], dict2[k])
        else:
            dict1[k] = dict2[k]
    return dict1


def setup_hosts(roledefs):
    hosts = set()
    for v in roledefs.values():
        hosts |= set(v)

    env.hosts = list(hosts)
    return env.hosts


def setup_etcd_proxy_roles(hosts, roledefs):
    if not roledefs.get('etcd-proxy', None):
        etcd_proxy = set(hosts) - set(roledefs.get('etcd', []))
        roledefs['etcd-proxy'] = list(etcd_proxy)


def construct_env(env_data, default_env_data=None):
    if not default_env_data:
        default_env_data = yaml.safe_load(
            open(constants.default_configs).read()
        )

    env_data = merge_dicts(env_data, default_env_data)
    env['configs'] = env_data
    fabric_override = env_data.get('fabric', None)
    if fabric_override is not None:
        for k, v in fabric_override.items():
            env[k] = v

    host_string_user = parse_host_string(env.host_string)['user']
    env_data_user = env_data.get('user', None)
    if host_string_user:
        env['user'] = host_string_user
    elif env_data_user:
        env['user'] = env_data_user

    roledefs = env_data.get('roledefs', None)
    del env_data['roledefs']
    if roledefs:
        env['roledefs'] = roledefs
        hosts = setup_hosts(roledefs)
        setup_etcd_proxy_roles(hosts, roledefs)


def create_env_tasks(namespace):
    for config in glob.glob(constants.configs):
        env_data = yaml.safe_load(open(config).read())
        stage = os.path.splitext(os.path.basename(config))[0]
        create_env_task(stage, env_data, namespace)


def create_env_task(env_name, env_dict, namespace):
    def env_task():
        env.stage = env_name
        construct_env(env_dict)

    env_task.__doc__ = u'''Set environment for {0}'''.format(env_name)

    wrapper = task(name=env_name)
    rand = '%d' % (time.time() * 100000)
    namespace['task_%s_%s' % (env_name, rand)] = wrapper(env_task)


def generate_local_assets_env(host):
    certs_path = []
    for k, v in constants.LOCAL_ASSETS_PATH.items():
        certs_path.append(
            'export {}="{}"'.format(k, getattr(constants, k.lower())(host))
        )
    return [
        'export LOCAL_CERTS_DIR="%s"' % constants.certs_dir(),
    ] + certs_path


def generate_etcd_env():
    etcd_servers = ''
    if not is_selfhosted_etcd():
        etcd_servers = env.roledefs.get('etcd', None)
        if not etcd_servers:
            raise "etcd roles should be set!"
        etcd_servers = ["https://{}:2379".format(x) for x in etcd_servers]
        etcd_servers = ','.join(etcd_servers)

    return ['export ETCD_SERVERS="{}"'.format(etcd_servers)]


def master_list():
    servers = ' '.join(env.roledefs['master'])
    return ['export KUBE_MASTERS="{0}"'.format(servers)]


def generate_local_env():
    local_env = ['export LOCAL_ASSETS_DIR="%s"' % constants.assets_dir()]
    local_assets_env = generate_local_assets_env(env.host)
    return local_env + local_assets_env + generate_etcd_env() + master_list()


def is_selfhosted_etcd():
    return env['configs']['etcd']['selfhosted'] == 'true'


def run_script(script_name, *options, local_env=[]):
    with tempfile.TemporaryDirectory() as temp_dir:
        default_env = os.path.join(temp_dir, 'default-env.sh')
        utils.generate_env_file(
            default_env,
            env,
            local_env
        )

        local(
            'source {0} && bash {1}/{2} {3}'.format(
                default_env,
                constants.remora_scripts_dir,
                script_name,
                ' '.join(options)
            ),
            shell=env.configs['local']['shell'],
        )
