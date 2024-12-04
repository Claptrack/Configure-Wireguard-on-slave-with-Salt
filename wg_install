### This file should be on your master in /srv/salt/wg_install

wireguard-pkg:
    pkg.installed:
      - name: wireguard

#copy wg0.conf from master
copy-conf:
    file.managed:
      - name: /etc/wireguard/wg0.conf
      - source: salt://wg_install/wg0.conf
      - creates: /etc/wireguard/wg0.conf

#generating private key only if non-existent, do not print to stdout
generate-private-key:
    cmd.run:
      - name: wg genkey | sudo tee /etc/wireguard/private.key > /dev/null
      - creates: /etc/wireguard/private.key

#changing permission on private.key to 600 if private key was generated in previous cmd.run
change-permissions:
    cmd.run:
      - name: sudo chmod go= /etc/wireguard/private.key
      - onchanges:
        - cmd: generate-private-key

#generate publickey based on privatekey if file public.key does not exist
generate-public-key:
    cmd.run:
      - name: sudo cat /etc/wireguard/private.key | wg pubkey > /etc/wireguard/public.key
      - creates: /etc/wireguard/public.key

#copy private key to EOF /etc/wireguard/wg0.conf
copy-private-key:
    cmd.run:
      - name: sudo cat /etc/wireguard/private.key >> /etc/wireguard/wg0.conf
      - onchanges:
        - cmd: generate-public-key

#start service/create VPN tunnel with interface wg0
start-service:
    cmd.run:
      - name: sudo systemctl enable wg-quick@wg0.service
      - onchanges:
        - file: /etc/wireguard/wg0.conf
