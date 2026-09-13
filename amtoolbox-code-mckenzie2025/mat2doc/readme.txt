Required: Linux OS

Prepare your OS:
================

Install bibtex2html:
 sudo apt-get install bibtex2html
Install pygments and docutils:
 python3 -m pip install pygments
 python3 -m pip install docutils
To set the start of the correct Matlab version, optionally add a line with, e.g., 
 export PATH=/opt/MATLAB/R2019a/bin/:$PATH
to ".profile" in your home directory. By doing so, Matlab 2019a will be started when executing "matlab"

Prepare your AMT setup:
=======================

Get the AMT code:
   git clone git://git.code.sf.net/p/amtoolbox/code amtoolbox
   cd amtoolbox
 
Start Matlab: 
   matlab -nodesktop
check the Matlab's version (to ensure the 5-years backwards compatibility of the AMT)

In Matlab: 
   restoredefaultpath;   % remove any used-defined paths, if required
   savepath;             % remove any used-defined paths, if required
   amt_start('install'); % get all toolboxes and compile (check if compiled without errors)
   amt_stop;             % stop the AMT
   amt_start;            % check if no errors and no downloads but still all thirdparty toolboxes available.
   exit
Restart Matlab again and check with amt_start if all toolboxes have been loaded. 

Compiling the documentation:
============================

Go to ~/amtoolbox (if not already there):
  cd amtoolbox
  
Get most recent AMT code: 
  git pull
  
Compile to MAT files:
 python3 mat2doc/mat2doc.py . mat --outputdir ~/

Compile to PHP files: 
 No Matlab execution at all, the web pages display no figures (fastest way, but no figures):
   python3 mat2doc/mat2doc.py . php --no-plot --outputdir ~/ --upload
 Matlab execution only if _output files not available, the web pages display the old figures for which _output files provided (standard):
   python3 mat2doc/mat2doc.py . php --no-execplot --outputdir ~/ --upload
 Execute Matlab always when Matlab files newer than php files (slowest):
   python3 mat2doc/mat2doc.py . php --outputdir ~/ --upload

To debug the output of Matlab (and input to DocUtils): use flag --rst-debug. Mat2doc will exit after printing the output. 

Runs mat2doc MAT files without blocking the terminal. The output goes to ~/log-mat.txt:
 nohup python3 mat2doc/mat2doc.py . mat --outputdir ~/ > ~/log-mat.txt &

Runs mat2doc PHP files without blocking the terminal and without figures. The output goes to ~/log-php.txt: 
 nohup python3 mat2doc/mat2doc.py . php --no-execplot --outputdir ~/ --upload > ~/log-php.txt &

Delete the log files:
 rm ~/log*.txt

To check if the process still runs: 
 ps
If you see python3 and/or matlab, then mat2doc is still running, or 
 top
to see the processes in real-time.

Configuration help:
===================

use the file 'ignore-files' to provide file names of files to be excluded from mat2doc process.
use the file 'ignore-folders' to provide directories to be excluded from mat2doc process.
use the file 'nodocs-files' to provide file names of files to be copied only, not processed. (Untested!)
the parameter '--upload' copies the root PHP files to /base and adapts the PHP include paths. 

If git problems because of some local changes: 
 git fetch --all
 git reset --hard origin/develop
 git pull
If this does not work because of some unstashed changes, try this:
 git config core.filemode false
and then the reset and pull again. If still problems with ghosting files, remove them and then pull. 

To delete all PHP files from the directory:
 find ~/amtoolbox-php/ -name '*.php' -delete
 
To recreate figures in a directory, e.g., demos, delete png and _output in that directory:
 find ~/amtoolbox-php/demos/ -name '*.png' -delete
 find ~/amtoolbox-php/demos/ -name '*_output' -delete
 
If having problems with calling python from Matlab with libstdc++ library execute this before starting Matlab
 export LD_PRELOAD=/lib/x86_64-linux-gnu/libstdc++.so.6 matlab
 
To test if Matlab can process python scripts from the AMT, run in Matlab: 
 amt_extern('Python','test_python','test_modules.py',[],[]);
if no errors, good. 

 
Copy to the website:
====================
Copy the files from the www.../doc to the amtoolbox-php
Delete all PHP files in amtoolbox-php:
 find ~/amtoolbox-php/ -name '*.php' -delete
Start mat2doc for PHP with --no-execplot --upload
Copy the new PHP files from amtoolbox-php to a new www.../doc directory
Now, on the new website, the documentation are now updated, with the figures are still the old ones
