### This file should be on your master in /srv/salt/wg_last

pubkey-to-server:
    file.managed:
      - name: /etc/wireguard/public.key1
      - source: salt://wg_last/public.key1
      - append_if_not_found: True

pubkey-to-wg0:
    cmd.run:
      - name: sudo wg set wg0 peer $(cat /etc/wireguard/public.key1) allowed-ips 10.8.0.2,10.8.0.100
      - onchanges:
        - file: /etc/wireguard/public.key1

check-service:
    service.running:
      - name: wg-quick@wg0
