bauth - Store and Generate OATH one-time passwords in bash
==========================================================                                                                   

bauth is a bash script that automates the process of safely storing the secret keys of services that use two-step verification. It can also use the stored secret keys to generate one-time passwords.

Features
--------

Below is a list of features that bauth currently supports:
- **Multiple accounts per service**: You can register multiple secret keys for a single service by binding each one on a different email address.
- **OpenPGP public key encryption**: You can use your OpenPGP public key to encrypt the secret keys before storing them on disk.
- **Sharing**: You can store the encrypted secret keys on a cloud-based folder (e.g., Dropbox) in order to make them accessible to different systems.
- **Simple command line interface**: You can use bauth directly from your terminal.
    
Dependencies
------------    
bauth is just a bash script and depends on other utilities in order to function. Below, is a list of the utilities on which bauth depends:
- **oathtool**: bauth depends on oathtool in order to generate one-time passwords for particular services.
- **gpg**: bauth uses the OpenPGP encryption and signing tool for encryption and decryption operations.

How to use it
-------------
First, clone this repository to a local directory. Then, `cd` into the cloned directory and run `./bauth.sh -h` to see a help message.
You need to have a gpg key configured in order to use bauth. If not, now it is a good time to [create](https://www.gnupg.org/documentation/howtos.html) one. bauth can either use the provided email address (with the `-m` option) as a gpg user ID, or you can specify a different user ID with the `-u` option.
Suppose that the email address an@email is a valid user ID in your gpg key. To register a new secret key type the following: 
```
./bauth.sh -p -s=a_service -e=an@email -k=secret_key
```
To retrieve a one-time password for a registered service type the following:
```
./bauth.sh -g -s=a_service -e=an@email
```
To delete a secret key type the following:
```
./bauth.sh -d -s=a_service -e=an@email
```
By default, bauth uses the `~/.bauth/` directory as its home directory where it stores its `pool.gpg` file. However, you can change this location, either by using the `-m` option or by modyfing the `bauth.sh` script directly (look for the `BAUTH_HOME` variable). 
A use-case of this feature is to let you share the secret keys with multiple systems. You can accomplish this by specifying a cloud-based directory (e.g., Dropbox) as the home folder of bauth. As the `pool.gpg` file is always stored in encrypted form, no secret key can be leaked to the cloud provider.

Below is a complete list of the supported options:
```
-p, --put               Store a service key for a new service.
-g, --get               Get an one-time password.
-r, --remove            Remove an one-time password.
-s, --service=SERVICE   Specify a service name.
-e, --email=EMAIL       Specify an email address.
-k, --key=KEY           Specify a service secret key.
-m, --bauth-home=       Specify the home location of the bauth tool.
-h, --help              Print a help message and exit.
-v, --version           Print the version number nd exit
```
    
How it works
------------
bauth uses a file which is called `pool.gpg` to store the secret keys of each service. This file may contain multiple secret keys for the same service, where each one corresponds to a different user email address.  Before storing this file on disk, bauth uses OpenPGP to encrypt it with the public key of the user.
To add a new secret key to the `pool.gpg`, bauth performs the following steps:
1. Decrypts the `pool.gpg` file in memory.
2. Appends the in-memory plaintext with the new secret key using the form: `service-email key`.
3. Encrypts the in-memory plaintext and replaces the old `pool.gpg` file. 

To retrieve a secret key from the `pool.gpg` bauth performs the following steps:
1. Decrypts the `pool.gpg` file in memory.
2. Finds the entry that corresponds to a combination of a service and an email.
3. Provides the secret key of this entry to oathtool.

Bugs
----
If you find a bug, please report it to the issues section. 

License
-------
bauth is available under the terms of the GPL-3.0. See LICENSE for details.
