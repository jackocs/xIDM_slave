#!/bin/bash

echo ""
echo "Currently supports only CentOS 7"
echo ""
echo "Select the installation you wish to perform:"
echo ""
echo "1. Install LDAP Slave Replication"
echo ""
read -p "Select installation (1 or (Q)uit): " input

chLDAPMATER() {
	ip=$1
	basedn=$2
	admin=$3
	pass=$4

	#echo "$ip : $basedn : $admin : $pass"
	yum -y install openldap-clients
	chLDAP=$(/bin/ldapsearch -LLL -o nettimeout=3 -x -h $ip -b "$basedn" -D "$admin,$basedn" -w $pass uid=admin dn |grep "dn" |wc -l |tr -d "\n\r")
	#echo $chLDAP
}

if [[ $input =~ ^(1| ) ]] ; then
	echo ""
	read -p "Would you like to continue (y/n) ?:" confirm
	if [[ $confirm =~ ^(y|Y| ) ]] ; then
		echo "Installing LDAP Slave...."
		echo ""
		#/bin/yum -y install gnutls-utils curl mariadb git openldap-* perl-LDAP perl-Time-Piece perl-Switch.noarch perl-Switch perl-DateTime perl-DB_File perl-DBI perl-DBD-MySQL epel-release python-pip perl-CPAN
		/bin/yum -y install gnutls-utils curl git openldap-* perl-LDAP perl-Time-Piece perl-Switch.noarch perl-Switch perl-DateTime perl-DB_File perl-DBI perl-DBD-MySQL epel-release python-pip gcc-c++ make gcc
		#(echo y;echo o conf prerequisites_policy follow;echo o conf commit)|cpan
		#cpan MongoDB
		/bin/curl --silent --location https://rpm.nodesource.com/setup_8.x | sudo bash -
		/bin/yum -y install nodejs
		/bin/yum upgrade -y python*
		#pip install --upgrade pip
		#python -m pip install python-ldap mysql-connector pymongo python-dateutil datetime timedelta
		if [ ! -d "/home/restful_node_slave" ]; then
			/bin/cd /home/
			/bin/git clone https://github.com/jackocs/restful_node_slave.git /home/restful_node_slave
			/bin/cd /home/restful_node_slave
		fi

		if (( $(ps -ef | grep -v grep | grep "node_slave" | wc -l) == 0 )) ; then
			/bin/cp /home/restful_node_slave/identifier.service /usr/lib/systemd/system/
			chmod +x /usr/lib/systemd/system/identifier.service
			systemctl daemon-reload
			systemctl enable identifier.service
			systemctl start identifier.service
		fi

		echo "========================================="
		echo ""
		read -p "Enter the Primary LDAP Master IP address: " ipmaster
		echo ""
		if [ -z "$ipmaster" ] ; then
			echo "Error: null value in entry: LDAP Master IP address"
			exit
		fi

		# Check ACL Permit Master
		check=$(/bin/curl --silent http://$ipmaster:3000/api/v1/node)
		if [ "$check" != "OK" ]; then
        		echo "Error: Could not open a connection to LDAP Master: $ipmaster"
        		exit
		fi

		read -p "Enter the LDAP Domain: " domain
		echo ""
		if [ -z "$domain" ] ; then
			echo "Error: null value in entry: LDAP domain"
			exit
		fi
		read -p "Enter the LDAP Administration user ID [cn=manager]: " admin
		echo ""
		echo -n "Enter the LDAP Administration password []: " 
		read -s adminpass
		echo ""
		if [ -z "$adminpass" ] ; then
			echo "Error: null value in entry: LDAP Administration password"
			exit
		fi
		if [ -z "$admin" ] ; then
			admin="cn=manager"
		fi

		for i in $(echo $domain | tr "." "\n")
		do
        		base="$base,dc=$i"
		done
		basedn=`echo $base |cut -c 2-`

		echo ""
		ipslave=$(hostname -I |cut -f1 -d" ")
		read -p "Enter the IP Address LDAP SLAVE [$ipslave]: " ipslaveNew
		echo ""
		if [ "$ipslaveNew" ] ; then
			ipslave="$ipslaveNew"
		fi

		read -p "Enter the LDAP SLAVE Description [slave_$ipslave]: " desc
		echo ""
		if [ -z "$desc" ] ; then
			desc="slave_$ipslave"
		fi

		echo "LDAP SLAVE IP Address: $ipslave"
		echo "LDAP SLAVE Description: $desc"
		echo "LDAP Master IP Address: $ipmaster"
		echo "Domain: $domain"
		echo "BaseDN: $basedn"
		echo "admin: $admin"
		#echo "admin pass: $adminpass"

		chLDAPMATER $ipmaster $basedn $admin $adminpass
		if [ $chLDAP != 1 ] ; then
			exit
		fi
		#echo $chLDAP

		if (( $(/bin/yum-config-manager | grep -v grep | grep "docker-ce" | wc -l) == 0 )) ; then
			/bin/yum -y remove docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-selinux docker-engine-selinux docker-engine
			#/bin/yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
			#/bin/yum-config-manager --enable docker-ce-edge
		fi
		if (( $(rpm -qa |grep "docker-ce" |grep -v grep | wc -l) == 0 )) ; then
			#/bin/yum install -y docker-ce
			rpm -ivh ./Packages/docker-ce-18.09.6-3.el7.x86_64.rpm
			rpm -ivh ./Packages/docker-ce-cli-18.09.6-3.el7.x86_64.rpm
			/bin/pip install docker-compose
			systemctl start docker
			systemctl enable docker
		fi
		ck_docker=$(systemctl is-active docker)
		if [ $ck_docker != "active" ] ; then 
			systemctl start docker
			systemctl enable docker
		fi
		
		#/bin/yum install -y https://centos7.iuscommunity.org/ius-release.rpm
		#/bin/yum install -y python36u python36u-libs python36u-devel python36u-pip
		#pip3.6 install --upgrade pip
		#python3.6 -m pip install python-ldap mysql-connector pymongo python-dateutil datetime timedelta

		if [ ! -d "/home/ldap_slave" ]; then
			/bin/cd /home/
                        /bin/git clone https://github.com/jackocs/ldap_slave.git /home/ldap_slave
		fi
		
		ckSlpad=$(/bin/curl --silent http://$ipslave:3000/api/v1/dir/install/$domain/$adminpass/$ipslave/$desc/3/$ipmaster/admin)
		#echo $ckSlpad

		if [ $ckSlpad == "ok" ] ; then
			updateDB=$(/bin/curl --silent http://$ipmaster:3000/api/v1/dir/install/$domain/$adminpass/$ipslave/$desc/3/admin)
			echo $updateDB
		fi
	fi
fi
