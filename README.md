# svn2git

## Description
A modified version of https://github.com/schwern/svn2git/ in Bash Script

## Installation:

Just copy svn2git.sh to your system

**Requirements:**
* git 2.20.1
* git-svn 2.20.1 (svn 1.10.0)
* getopt 1.1.6

**Note:**
It may work on lower versions but I tested it on the specified list

## Execution and parameters
Excute by putting the script on your PATH envirnoment variable o by typing:

```./svn2git.sh [OPTIONS] <SVN_URL>```

```SVN_URL```: Specifies the subversion url where your current project lives.

**OPTIONS**

* **--verbose**: Prints debug messages and git commands being executed
* **--notrunk**: Indicates git that there is no **trunk** path in the current repository
* **--no-branches**: Indicates git that there is no **branches** path in the current repository
* **--notags**: Indicates git that there is no **tags** path in the current repository
* **--logrev**: NOT YET SUPPORTED
* **--trunk**: The path to trunk in svn repositoroy by default **trunk**
* **--branches**: The path to branches in svn repository by default **branches**
* **--tags**: The path to tags in svn repository by default **tags**
* **--authors**: The path to authors file
* **--no-metadata**: Tells git-svn to process repository with no metadata
* **--help**: Information about the script





