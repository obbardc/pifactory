#
# superclouder is a project which aims to help you create a supercomputer
#   in the cloud.
#
# We aren't to sure what it will do either
#

import paramiko.client
import paramiko.util

class Client(object):
    def __init__(self, hostname, port, username, password):
        self.hostname = hostname
        self.port = port
        self.username = username
        self.password = password

    def connect(self):
        # do not log
        paramiko.util.log_to_file("/dev/null")

        self.client = paramiko.client.SSHClient()

        # auto accept the host key to this session (warning: security f*ck up)
        self.client.set_missing_host_key_policy(paramiko.client.AutoAddPolicy())

        try:
            self.client.connect(hostname=self.hostname, port=self.port, username=self.username, password=self.password, timeout=1, look_for_keys=False)
        except Exception, e:
            return False

        return True

    def copy_file_sftp(self, local, remote):
        sftp = self.client.open_sftp()
        sftp.put(local, remote)
        sftp.close()

    def exec_command(self, command):
        import time
        transport = self.client.get_transport()
        session = transport.open_session()
        session.setblocking(0)
        session.exec_command(command)

        stdout, stderr = '', ''
        while True:  # monitoring process
            # Reading from output streams
            while session.recv_ready():
                stdout += session.recv(1000)
            while session.recv_stderr_ready():
                stderr += session.recv_stderr(1000)
            if session.exit_status_ready():  # If completed
                break
            time.sleep(0.001)
        retcode = session.recv_exit_status()

        return (stdout, stderr, retcode)

    def close(self):
        self.client.close()