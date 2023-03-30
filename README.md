# Putty shell
This solution allow to use putty's sessions inside Windows Terminal and not only.

## How to setup
1. `git clone git@github.com:SailorMax/psh.git`
2. right mouse click on ps1-file / Properties / `Unblock`
3. try to exec `psh.bat`. It has to output all putty session names and suggest to choose anyone to connect
4. add to `PATH` your clone-directory (SystemPropertiesAdvanced / Enviroment Variables... / User variables)
5. open Windows Terminal and execute `psh` (as second argument you can use word to filter sessions list)
<br /><br />

---
### Start using Windows ssh-agent:
1. remove from memory git's `ssh-agent` (via task manager), remove user's variables `SSH_AGENT_PID` and `SSH_AUTH_SOCK` (via SystemPropertiesAdvanced / Enviroment Variables...), remove from `PATH` directory of Git's (or similar) ssh (if it exists there)
2. install via Windows "Optional features" `OpenSSH client`
3. if actual, prepare Git to use system's ssh: `git config --global core.sshCommand "'C:\Windows\System32\OpenSSH\ssh.exe'"`
4. if require, prepare file similar to `config/add_default_key_to_agent.bat` or use this one in autostart/manual setup ssh-agent after each Windows restart.
5. to use new `PATH` some programs require restart
