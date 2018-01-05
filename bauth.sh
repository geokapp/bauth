#!/bin/bash
#
#  bauth - Store and Generate OATH one-time passwords in bash.
#
#  Copyright (C) 2018 Giorgos Kappes <giorgos@giorgoskappes.com>
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
BAUTH_HOME="${HOME}/.bauth"
BAUTH_KEY=""
BAUTH_SERVICE=""
BAUTH_EMAIL=""
BAUTH_OPERATION=""
BAUTH_DEPS="mkdir mv cat sed rm grep echo oathtool gpg"
BAUTH_BASE="base32"
BAUTH_TYPE="totp"
BAUTH_DIGITS="6"
BAUTH_OATHTOOL="oathtool --${BAUTH_BASE} --${BAUTH_TYPE} -d ${BAUTH_DIGITS}"
BAUTH_GPG="gpg -q"
BAUTH_VERSION="1.0.0"
GPG_UID=""

#
# check-deps - Checks if the required utilities are installed.
#
check-deps ()
{
    for i in ${BAUTH_DEPS}; do
	if ! hash ${i} 2> /dev/null; then
	    echo "Error: ${i} not found."
	    exit 1
	fi
    done
}    

#
# show-help - Prints a help message.
#
show-help()
{
    echo "Usage: bauth [OPTION]..."
    echo "Store and Generate OATH one-time passwords in bash."
    echo ""
    echo "Available Options:"
    echo "-p, --put               Store a service key for a new service."
    echo "-g, --get               Get an one-time password."
    echo "-r, --remove            Remove an one-time password."
    echo "-s, --service=SERVICE   Specify a service name."
    echo "-e, --email=EMAIL       Specify an email address."
    echo "-k, --key=KEY           Specify a service secret key."
    echo "-m, --bauth-home=PATH   Specify the home location of the bauth tool."    
    echo "-u, --user-id=UID       Specify an OpenPGP user ID."
    echo "-h, --help              Print a help message and exit."
    echo "-v, --version           Print the version number and exit"
}

#
# show-version - Prints the version number.
#
show-version()
{
    echo "bauth version ${BAUTH_VERSION}"
    echo
    echo "Copyright (C) 2018 Giorgos Kappes <giorgos@giorgoskappes.com>"
    echo "License GPLv3 GNU GPL version 3 <http://gnu.org/licenses/gpl.html>."
    echo "This is free software: you are free to change and redistribute it."
    echo "There is NO WARRANTY, to the extent permitted by law."
}

#
# bauth-init - Creates an empty storage pool.
#
bauth-init()
{
    if ! echo "########" > ${BAUTH_HOME}/pool.gpg; then
	return 1
    fi
    if ! ${BAUTH_GPG} ${GPG_UID} -o ${BAUTH_HOME}/pool.gpg.tmp --encrypt ${BAUTH_HOME}/pool.gpg 2> /dev/null ; then
	return 1
    fi
    mv ${BAUTH_HOME}/pool.gpg.tmp ${BAUTH_HOME}/pool.gpg     
    return 0
}

#
# bauth-exists - Checks if the storage pool contains an entry for a service-email.
#
bauth-exists()
{
    if ${BAUTH_GPG} ${GPG_UID} --decrypt ${BAUTH_HOME}/pool.gpg 2> /dev/null | grep "${BAUTH_SERVICE}-${BAUTH_EMAIL}" ; then
	return 0;
    fi
    return 1
}

#
# bauth-get - Retrieves an one-time password for a service-email.
#
bauth-get()
{
    if [ "$BAUTH_SERVICE" == "" ]; then
	echo "Error: a service name is needed."
	exit 1
    fi

    if [ "$BAUTH_EMAIL" == "" ]; then
	echo "Error: an email address is needed."
	exit 1
    fi

    if [ ! -d ${BAUTH_HOME} ]; then
	echo "Error: the directory ${BAUTH_HOME} does not exist."
	exit 1
    fi
    
    if [ ! -f ${BAUTH_HOME}/pool.gpg ]; then
	echo "Error: the store is empty."
	exit 1	
    fi

    if ! bauth-exists 1> /dev/null ; then
	echo "Error: no entry for ${BAUTH_SERVICE} (${BAUTH_EMAIL})."
	exit 1
    fi

    if ! ${BAUTH_OATHTOOL} $(${BAUTH_GPG} ${GPG_UID} --decrypt ${BAUTH_HOME}/pool.gpg 2> /dev/null | \
				   grep "${BAUTH_SERVICE}-${BAUTH_EMAIL}" | cut -d " " -f2); then
	exit 1;
    fi
    exit 0
}

#
# bauth-put - Stores a service secret key for a service-email.
#
bauth-put()
{
    if [ "$BAUTH_SERVICE" == "" ]; then
	echo "Error: a service name is needed."
	exit 1
    fi

    if [ "$BAUTH_EMAIL" == "" ]; then
	echo "Error: an email address is needed."
	exit 1
    fi

    if [ "$BAUTH_KEY" == "" ]; then
	echo "Error: a service secret key is needed."
	exit 1
    fi

    if [ ! -d ${BAUTH_HOME} ]; then
	read -p "The directory ${BAUTH_HOME} does not exist. Should I create it (Y/n)? " -n 1 -r
	echo
	if [[ $REPLY =~ ^[Yy]$ ]]; then
	    mkdir ${BAUTH_HOME} || exit 1 ;
	else
	    exit 1;
	fi
    fi
    
    if [ ! -f ${BAUTH_HOME}/pool.gpg ]; then
	if ! bauth-init; then
	    exit 1
	fi
    fi
    
    if bauth-exists 1> /dev/null ; then
	echo "Error: an entry for ${BAUTH_SERVICE} (${BAUTH_EMAIL}) already exists."
	exit 1
    fi

    if ! cat <(${BAUTH_GPG} -q ${GPG_UID} --decrypt ${BAUTH_HOME}/pool.gpg 2> /dev/null) \
	 <(echo "${BAUTH_SERVICE}-${BAUTH_EMAIL} ${BAUTH_KEY}") | \
	    ${BAUTH_GPG} -q ${GPG_UID} -o ${BAUTH_HOME}/pool.gpg.tmp --encrypt 2> /dev/null; then
	exit 1
    fi
    mv ${BAUTH_HOME}/pool.gpg.tmp ${BAUTH_HOME}/pool.gpg &&
    echo "${BAUTH_SERVICE} (${BAUTH_EMAIL}) added." 
    exit 0
}

#
# bauth-remove - Removes the entry that corresponds to a service-email.
#
bauth-remove()
{
    if [ "$BAUTH_SERVICE" == "" ]; then
	echo "Error: a service name is needed."
	exit 1
    fi

    if [ "$BAUTH_EMAIL" == "" ]; then
	echo "Error: an email address is needed."
	exit 1
    fi

    if [ ! -d ${BAUTH_HOME} ]; then
	echo "Error: the directory ${BAUTH_HOME} does not exist."
	exit 1
    fi
    
    if [ ! -f ${BAUTH_HOME}/pool.gpg ]; then
	echo "Error: the store is empty."
	exit 1
    fi
    
    if ! ${BAUTH_GPG} ${GPG_UID} --decrypt ${BAUTH_HOME}/pool.gpg 2> /dev/null | \
	    sed "/${BAUTH_SERVICE}-${BAUTH_EMAIL}/d" | \
	    ${BAUTH_GPG} ${GPG_UID} -o ${BAUTH_HOME}/pool.gpg.tmp --encrypt 2> /dev/null; then	
	rm ${BAUTH__HOME}/pool.gpg.tmp 2> /dev/null
	exit 1
    fi

    read -p "Are you sure (Y/n)? " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
	rm ${BAUTH_HOME}/pool.gpg.tmp
	exit 0
    fi
    mv ${BAUTH_HOME}/pool.gpg.tmp ${BAUTH_HOME}/pool.gpg &&
    echo "${BAUTH_SERVICE} (${BAUTH_EMAIL}) deleted." 
    exit 0
}
    
# Parse user arguments.
for i in "$@"
do
    case $i in
	-h|--help)
	    eval show-help
	    exit 0
	    ;;
	-p|--put)
	    BAUTH_OPERATION="bauth-put"
	    shift
	    ;;
	-g|--get)
	    BAUTH_OPERATION="bauth-get"
	    shift
	    ;;
	-r|--remove)
	    BAUTH_OPERATION="bauth-remove"
	    shift
	    ;;
	-v|--version)
	    eval show-version
	    exit 0
	    ;;
	-s=*|--service=*)
	    BAUTH_SERVICE=${i#*=}
	    if [ "$BAUTH_SERVICE" == "" ]; then
		echo "Error: the service parameter was not specified. Run with -h for help."
		exit 1
	    fi
	    shift
	    ;;
	-k=*|--key=*)
	    BAUTH_KEY=${i#*=}
	    if [ "$BAUTH_KEY" == "" ]; then
		echo "Error: the key parameter was not specified. Run with -h for help."
		exit 1
	    fi
	    shift
	    ;;
	-e=*|--email=*)
	    BAUTH_EMAIL=${i#*=}
	    if [ "$BAUTH_EMAIL" == "" ]; then
		echo "Error: the email parameter was not specified. Run with -h for help."
		exit 1
	    fi
	    shift
	    ;;
	-m=*|--bauth-home=*)
	    BAUTH_HOME=${i#*=}
	    if [ "$BAUTH_HOME" == "" ]; then
		echo "Error: the authenticator home path was not specified. Run with -h for help."
		exit 1
	    fi
	    shift
	    ;;
	-u=*|--user-id=*)
	    GPG_UID=${i#*=}
	    if [ "$GPG_UID" == "" ]; then
		echo "Error: the user ID was not specified. Run with -h for help."
		exit 1
	    fi
	    shift
	    ;;
	*)
	    echo "Error: $i: unrecognized option. Run with -h for help."
	    exit 1
	    ;;
    esac
done

if [ "$BAUTH_OPERATION" != "" ]; then
    # Check dependencies.
    check-deps

    # Select a valid GPG user ID.
    if [ "${GPG_UID}" == "" ]; then
	if ! ${BAUTH_GPG} --list-keys ${BAUTH_EMAIL} 2> /dev/null > /dev/null ; then
	    echo "Error: the provided email does not correspond to a user ID in your GPG key."
	    echo "Note: you can use the -u option to specify a GPG user ID."
	    exit 1
	fi
	GPG_UID="-r ${BAUTH_EMAIL}"
    else
	if ! ${BAUTH_GPG} --list-keys ${GPG_UID} 2> /dev/null > /dev/null ; then
	    echo "Error: the provided user ID does not correspond to a user ID in your GPG key."
	    exit 1
	fi
	GPG_UID="-r ${GPG_UID}"
    fi

    # Call the requested operation.
    eval ${BAUTH_OPERATION}
else    
    show-help
    exit 0
fi
