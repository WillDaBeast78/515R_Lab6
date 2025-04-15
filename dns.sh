#!/bin/bash

# Function to install and configure BIND9 on Ubuntu 20.04
setup_dns_ubuntu() {
    echo "Setting up DNS on Ubuntu 20.04"
    sudo apt update || { echo "Failed to update packages"; exit 1; }
    sudo apt install -y bind9 bind9utils bind9-doc || { echo "Failed to install BIND9"; exit 1; }
    sudo systemctl start named || { echo "Failed to start named"; exit 1; }
    sudo systemctl enable named || { echo "Failed to enable named"; exit 1; }

    # Configure BIND9
    sudo tee /etc/bind/named.conf.options > /dev/null <<EOL
options {
    directory "/var/cache/bind";

    recursion yes;
    allow-query { any; };

    forwarders {
        8.8.8.8;
        8.8.4.4;
    };

    dnssec-validation auto;

    auth-nxdomain no;    # conform to RFC1035
    listen-on-v6 { any; };
};
EOL

    # Append zone configurations to named.conf.local
    sudo tee -a /etc/bind/named.conf.local > /dev/null <<EOL
zone "team3.cyberjousting.org" IN {
    type master;
    file "/etc/bind/externalforward.db";
};

zone "team3.net" IN {
    type master;
    file "/etc/bind/internalforward.db";
};

zone "103.168.192.in-addr.arpa" IN {
    type master;
    file "/etc/bind/internalreverse.db";
};

zone "103.18.172.in-addr.arpa" IN {
    type master;
    file "/etc/bind/externalreverse.db";
};
EOL

    # Create zone files
    sudo tee /etc/bind/internalforward.db > /dev/null <<EOL
\$TTL 86400
@    IN    SOA    ns1.team3.net. admin.team3.net. (
                        2025022204 ; Serial
                        3600       ; Refresh
                        1800       ; Retry
                        604800     ; Expire
                        86400      ; Minimum TTL
)
@    IN    NS    ns1.team3.net.
ns1    IN    A    192.168.103.2
www    IN    A    192.168.103.3
db    IN    A    192.168.103.4
EOL

    sudo tee /etc/bind/internalreverse.db > /dev/null <<EOL
\$TTL 86400
@    IN    SOA    ns1.team3.net. admin.team3.net. (
                        2025022205 ; Serial
                        3600       ; Refresh
                        1800       ; Retry
                        604800     ; Expire
                        86400      ; Minimum TTL
)
@    IN    NS    ns1.team3.net.
2    IN    PTR    ns1.team3.net.
3    IN    PTR    www.team3.net.
4    IN    PTR    db.team3.net.
EOL

    sudo tee /etc/bind/externalforward.db > /dev/null <<EOL
\$TTL 86400
@    IN    SOA    ns1.team3.cyberjousting.org. admin.team3.cyberjousting.org. (
                        2025022202 ; Serial
                        3600       ; Refresh
                        1800       ; Retry
                        604800     ; Expire
                        86400      ; Minimum TTL
)
@    IN    NS    ns1.team3.cyberjousting.org.
ns1    IN    A    172.18.103.1
www    IN    A    172.18.103.1
shell    IN    A    172.18.103.2
files    IN    A    172.18.103.2
EOL

    sudo tee /etc/bind/externalreverse.db > /dev/null <<EOL
\$TTL 86400
@    IN    SOA    ns1.team3.cyberjousting.org. admin.team3.cyberjousting.org. (
                        2025022203 ; Serial
                        3600       ; Refresh
                        1800       ; Retry
                        604800     ; Expire
                        86400      ; Minimum TTL
)
@    IN    NS    ns1.team3.cyberjousting.org.
1    IN    PTR    ns1.team3.cyberjousting.org.
1    IN    PTR    www.team3.cyberjousting.org.
2    IN    PTR    shell.team3.cyberjousting.org.
2    IN    PTR    files.team3.cyberjousting.org.
EOL

    sudo systemctl restart named || { echo "Failed to restart named"; exit 1; }
    echo "BIND9 configured and restarted on Ubuntu 20.04"
}

# Function to add DNS A record
add_dns_record() {
    local hostname ip_address
    echo "Enter the hostname for the A record:"
    read hostname
    echo "Enter the IP address for the A record:"
    read ip_address

    # Add A record to internal forward zone
    echo "$hostname    IN    A    $ip_address" | sudo tee -a /etc/bind/internalforward.db > /dev/null

    # Extract last octet of IP address for reverse zone
    local last_octet=$(echo $ip_address | awk -F. '{print $4}')
    echo "$last_octet    IN    PTR    $hostname.team3.net." | sudo tee -a /etc/bind/internalreverse.db > /dev/null

    sudo systemctl restart named || { echo "Failed to restart named"; exit 1; }
    echo "DNS A record added and named restarted"
}

# Install and configure BIND9
setup_dns_ubuntu

# Add DNS A record
add_dns_record

# Error handling and logging
{
    echo "Script executed successfully"
} || {
    echo "An error occurred" >&2
}
