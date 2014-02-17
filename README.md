wptool
======

A command-line tool for looking at and fixing Wordpress installs.

Usage:

      wptool [dir] [options]
    
      Options:
        --check        Check MD5Sums
        --diff [path]  Show a diff of all changed files or, optionally, of the 
                       file at [path] relative to the dir.
        --fix          Check MD5Sums and replace changed files with new ones
        --help         See this help
        --mysql        Start a MySQL shell using credentials in wp-config.php
        --perms        Guess at sensible fs ownership and permissions; prompt 
                       to set them
        --user [name]  Override the unix user guessed by --perms
        --version      Print Wordpress version
        -V             Print the version of wptool


The options are more like (and should probably have been implemented as) commands. This 
tool uses a repository of Wordpress installs and associated MD5sum text files that can
be found here:

    http://wpsums.avi.co/

You can use a different URL by setting the evironment variable `WPSUMS_WORDPRESSES_URL`; 
that should be a URL to a directory containing a series of subdirectories each named
for a specific version; http://wpsums.avi.co/wordpresses/ is the default.

check
-----

Reads version.php, downloads the appropriate md5sums.txt file and checks each 
file in the instal has the 'correct' md5sum. The names of any that don't match 
are printed to stdout:

    avi@amazing:~$ wptool /home/avi/web/wordpress/public_html/ --check 
    changed: index.php
    changed: wp-includes/feed.php
    missing: wp-cron.php
    avi@amazing:~$ 


diff
----

Does a check and then prints a diff for each changed file:

    avi@amazing:~$ wptool /home/avi/web/wordpress/public_html/ --diff
    # < = Lines removed
    # > = Lines added
    index.php:
    1a2
    > include(/tmp/naughtythings.php)
    wp-includes/feed.php:
    179c179,183
    < 	echo apply_filters('the_excerpt_rss', $output);
    ---
    >		echo get_the_content_feed($feed_type);
    > 	}else{
    > 		echo apply_filters('the_excerpt_rss', $output);
    > 	}
    avi@amazing:~$ 

fix
---

Does a check and downloads new files to replace any changed or absent ones; 
no backups are taken:

    avi@amazing:~$ wptool /home/avi/web/wordpress/public_html/ --fix
    Changed: wp-includes/feed.php replaced
    Changed: index.php replaced
    Missing: wp-cron.php replaced
    avi@amazing:~$

mysql
-----

Parses wp_config.php and opens a MySQL shell using the credentials contained
therein:

    avi@amazing:~$ wptool /home/avi/web/wordpress/public_html/ --mysql
    Reading table information for completion of table and column names
    You can turn off this feature to get a quicker startup with -A
    
    Welcome to the MariaDB monitor.  Commands end with ; or \g.
    Your MariaDB connection id is 104
    Server version: 5.5.34-MariaDB-1~wheezy-log mariadb.org binary distribution
    
    Copyright (c) 2000, 2013, Oracle, Monty Program Ab and others.
    
    Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.
    
    MariaDB [wordpress]> 


perms
-----

Finds the owner of the directory passed and prompts to run these commands on it:

    chown <user>:www-data <dir> -R
    find <dir> -type f -exec chmod 740 {} \;
    find <dir> -type d -exec chmod 750 {} \;
	  chmod g+rws,u+s <dir>/wp-content/uploads -R

And, if <dir>/cgi-bin is found:

		chown <user>:<user> <dir>/cgi-bin/ -R
		chmod 755 <dir>/cgi-bin/ -R

The username may be overriden with the `--user` switch; you are prompted
with the suggested commands before they are run.


version
-------

Prints the version string as found in version.php:

    avi@amazing:~$ wptool /home/avi/web/wordpress/public_html/ --version
    3.8.1
		avi@amazing:~$

