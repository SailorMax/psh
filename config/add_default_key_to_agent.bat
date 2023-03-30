@echo off

rem add default user's key (at ~/.ssh/)
ssh-add

rem add specific user's key
rem ssh-add path_to_key

rem output stored keys
ssh-add -l

pause
