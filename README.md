# Putty shell
This solution allow to use putty's sessions inside Windows Terminal and not only.

Just execute `psh` and choose required session.

## How to setup
1. `git clone https://github.com/SailorMax/psh.git`
2. execute `psh.bat`. It has to output all putty session names and suggest to choose anyone to connect. In case of session_chooser.ps1 is not executable try: right mouse click on ps1-file / Properties / `Unblock`
3. add to `PATH` your clone-directory (SystemPropertiesAdvanced / Enviroment Variables... / User variables)
4. open Windows Terminal and execute `psh` (as second argument you can use word to filter sessions list or directly host:port)
<br /><br />

---
### Start using Windows 11 ssh-agent (WinSSH):
1. remove from memory git's `ssh-agent` (via task manager), remove user's variables `SSH_AGENT_PID` and `SSH_AUTH_SOCK` (via SystemPropertiesAdvanced / Enviroment Variables...), remove from `PATH` directory of Git's (or similar) ssh (if it exists there)
2. install via Windows "Optional features" `OpenSSH client`
3. if actual, prepare Git to use system's ssh: `git config --global core.sshCommand "'C:\Windows\System32\OpenSSH\ssh.exe'"`
4. if require, prepare file similar to `config/add_default_key_to_agent.bat` or use this one in manual setup ssh-agent ("WinSSH" keep them between restarts).
5. to use new `PATH` some programs require restart


(!) Warning! Some programs still doesn't support "WinSSH" (DBeaver, for example). For them you can try to use Putty's Peagant as separate process. Or setup variables `SSH_AGENT_PID` and `SSH_AUTH_SOCK` for "WinSSH".
