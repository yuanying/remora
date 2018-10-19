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

from fabric.api import env
from fabric.api import execute
from fabric.api import parallel
from fabric.api import reboot
from fabric.api import require
from fabric.api import runs_once
from fabric.api import settings
from fabric.api import sudo
from fabric.api import task

from remora.fab.clean import etcd
from remora.fab.clean import kubernetes


@task
@parallel
def dependency():
    require('stage')
    with settings(warn_only=True):
        sudo('rm -rf {0}'.format(env['configs']['temp_dir']))
        if env['configs'].get('clean', {}).get('mode', 'soft') == 'soft':
            sudo('docker rm -f `docker ps -a -q`')
        else:
            sudo('systemctl stop docker && systemctl disable docker')
            sudo('rm -rf /var/lib/docker')
            sudo('systemctl daemon-reload && systemctl enable docker')

        sudo('rm -rf /var/lib/kubelet')
        for d in env['configs']['clean'].get('dirs', []):
             sudo('rm -rf {}'.format(d))
        else:
            pass
        reboot()


@task(default=True)
@runs_once
def all():
    execute(etcd.all)
    execute(kubernetes.all)
    execute(dependency)
