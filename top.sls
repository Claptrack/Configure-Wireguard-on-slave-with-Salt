### This file should be on your master in /srv/salt ###

base:
    '*':
      - wg_install
      - wg_local
      - wg_last
