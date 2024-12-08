### This file should be on your master in /srv/salt/wg_local

wireguard-pkg-local:
    pkg.installed:
      - name: wireguard

#copy wg0.conf from master
copy-conf-local:
    file.managed:
      - name: /etc/wireguard/wg0.conf
      - source: salt://wg_local/wg0.conf
      - creates: /etc/wireguard/wg0.conf

#generating private key only if non-existent, do not print to stdout
generate-private-key-local:
    cmd.run:
      - name: wg genkey | sudo tee /etc/wireguard/private.key > /dev/null
      - creates: /etc/wireguard/private.key

#changing permission on private.key to 600 if private key was generated in previous cmd.run
change-permissions-local:
    cmd.run:
      - name: sudo chmod go= /etc/wireguard/private.key
      - onchanges:
        - cmd: generate-private-key-local

#generate publickey based on privatekey if file public.key does not exist
generate-public-key-local:
    cmd.run:
      - name: sudo cat /etc/wireguard/private.key | wg pubkey | sudo tee > /etc/wireguard/public.key /srv/salt/wg_last/public.key1
      - creates: /etc/wireguard/public.key

#copy private key to EOF /etc/wireguard/wg0.conf
copy-private-key-local:
    cmd.run:
      - name: sudo cat /etc/wireguard/private.key >> /etc/wireguard/wg0.conf
      - onchanges:
        - cmd: generate-public-key-local

#start service/create VPN tunnel with interface wg0
start-service-local:
    cmd.run:
      - name: sudo systemctl enable wg-quick@wg0.service
      - onchanges:
        - file: /etc/wireguard/wg0.conf
