print("Upload Script: Copying root files to /base...")

import shutil

# copy the PHP files from root to /base
if os.path.isfile(conf.t.dir+'/amt_start.php'):
    shutil.move(conf.t.dir+'/amt_start.php', conf.t.dir+'/base/amt_start.php')
if os.path.isfile(conf.t.dir+'/amt_start_code.php'):
    shutil.move(conf.t.dir+'/amt_start_code.php', conf.t.dir+'/base/amt_start_code.php')
if os.path.isfile(conf.t.dir+'/changes.php'):
    shutil.move(conf.t.dir+'/changes.php', conf.t.dir+'/base/changes.php')
if os.path.isfile(conf.t.dir+'/changes_code.php'):
    shutil.move(conf.t.dir+'/changes_code.php', conf.t.dir+'/base/changes_code.php')

# adapt the PHP include path
with os.scandir(conf.t.dir+'/base') as it:
    for entry in it:
        if not entry.is_file():
            continue
        with open(entry.path, 'r') as file:
            filedata = file.read()
        filedata = filedata.replace('$path_include="../include/";', '$path_include="../../include/";')
        with open(entry.path, 'w') as file:
            file.write(filedata)
            