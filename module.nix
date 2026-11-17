# EPIVÍOSI WIKI : archives Wikipédia (et autres ZIM) hors-ligne via Kiwix.
#
# Les fichiers ZIM sont trop gros pour l'ISO : ils vivent sur une partition
# exFAT étiquetée EPIV-WIKI (préparable depuis Windows, macOS ou Linux, ou avec
# `sudo epiviosi-wiki-setup`). Quand elle est présente, elle est montée sur
# /wiki et kiwix-serve sert tous ses .zim sur http://127.0.0.1:8080.
#
# Ce module implémente l'option `epiviosi.wiki.enable`, déclarée par le socle
# EPIVÍOSI OS (modules/epiviosi-modules.nix).
{ config, lib, pkgs, ... }:
let
  cfg = config.epiviosi.wiki;
  label = "EPIV-WIKI";
  deviceUnit = "dev-disk-by\\x2dlabel-EPIV\\x2dWIKI.device";
  mountUnit = "wiki.mount";
  port = 8080;
  url = "http://127.0.0.1:${toString port}/";

  epiviosi-wiki-setup = pkgs.callPackage ./pkgs/epiviosi-wiki-setup { };

  # Sert tous les .zim de /wiki (et d'un niveau de sous-dossiers). Sans ZIM,
  # le service s'arrête proprement : le lanceur affiche alors la page d'aide.
  serve = pkgs.writeShellScript "epiviosi-wiki-serve" ''
    shopt -s nullglob nocaseglob
    zims=(/wiki/*.zim /wiki/*/*.zim)
    if [ ''${#zims[@]} -eq 0 ]; then
      echo "Aucun fichier .zim dans /wiki."
      exit 0
    fi
    echo "ZIM servis : ''${zims[*]}"
    exec ${lib.getExe' pkgs.kiwix-tools "kiwix-serve"} \
      --address 127.0.0.1 --port ${toString port} \
      --skipInvalid --blockexternal \
      "''${zims[@]}"
  '';

  # Lanceur du menu : la bibliothèque Kiwix si elle répond, sinon l'aide.
  launcher = pkgs.writeShellScriptBin "epiviosi-wiki" ''
    PATH=${lib.makeBinPath [ pkgs.curl pkgs.coreutils ]}:$PATH
    shopt -s nullglob nocaseglob
    zims=(/wiki/*.zim /wiki/*/*.zim)
    if [ ''${#zims[@]} -gt 0 ]; then
      # Juste après le démarrage, un branchement ou une copie, le serveur
      # peut mettre quelques secondes à répondre.
      for _ in $(seq 15); do
        curl -sf -o /dev/null ${url} && exec firefox ${url}
        sleep 1
      done
    fi
    exec firefox file:///etc/epiviosi/wiki/aide.html
  '';

  desktopItem = pkgs.makeDesktopItem {
    name = "epiviosi-wiki";
    desktopName = "EPIVÍOSI WIKI";
    genericName = "Wikipédia hors-ligne";
    comment = "Consulter Wikipédia et les archives ZIM hors-ligne (Kiwix)";
    exec = "epiviosi-wiki";
    icon = "accessories-dictionary";
    categories = [
      "Education"
      "Office"
    ];
    keywords = [
      "wikipedia"
      "kiwix"
      "zim"
      "encyclopédie"
    ];
  };
in
{
  config = lib.mkIf cfg.enable {
    boot.supportedFilesystems.exfat = true;

    # Monté à l'apparition de la partition, comme EPIVIOSI-DATA : le démarrage
    # n'attend jamais un disque absent. Le groupe « users » peut écrire, pour
    # déposer des ZIM depuis EPIVÍOSI ; tout le monde peut lire (kiwix-serve).
    systemd.mounts = [
      {
        what = "/dev/disk/by-label/${label}";
        where = "/wiki";
        type = "exfat";
        options = "gid=${toString config.ids.gids.users},fmask=0113,dmask=0002,noatime";
        wantedBy = [ deviceUnit ];
      }
    ];

    # Partition déjà présente dans l'initrd : voir epiviosi-persist-boot.
    systemd.services.epiviosi-wiki-boot = {
      description = "Montage de la partition EPIVÍOSI WIKI présente au démarrage";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-udev-trigger.service" ];
      serviceConfig.Type = "oneshot";
      script = ''
        if [ -e /dev/disk/by-label/${label} ]; then
          systemctl start --no-block ${mountUnit}
        fi
      '';
    };

    systemd.services.epiviosi-wiki = {
      description = "EPIVÍOSI WIKI (kiwix-serve)";
      documentation = [ "https://kiwix-tools.readthedocs.io/en/latest/kiwix-serve.html" ];
      wantedBy = [ mountUnit ];
      bindsTo = [ mountUnit ];
      after = [ mountUnit ];
      serviceConfig = {
        Type = "exec";
        ExecStart = serve;
        Restart = "on-failure";
        RestartSec = 5;

        # Repris du module NixOS services.kiwix-serve.
        DynamicUser = true;
        CapabilityBoundingSet = "";
        DeviceAllow = "";
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateUsers = true;
        PrivateTmp = true;
        ProcSubset = "pid";
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectProc = "invisible";
        ProtectSystem = "strict";
        RemoveIPC = true;
        # AF_NETLINK : kiwix-serve vérifie l'adresse d'écoute via getifaddrs.
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_NETLINK"
          "AF_UNIX"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [
          "@system-service"
          "~@privileged"
          "~@resources"
        ];
        UMask = "0077";
      };
    };

    # Un ZIM ajouté ou retiré dans /wiki : on relance le serveur. Une copie
    # en cours est ignorée (--skipInvalid) puis prise en compte à la fin.
    systemd.paths.epiviosi-wiki-watch = {
      description = "Surveillance des ZIM de /wiki";
      wantedBy = [ mountUnit ];
      bindsTo = [ mountUnit ];
      after = [ mountUnit ];
      pathConfig = {
        PathChanged = "/wiki";
        Unit = "epiviosi-wiki-reload.service";
      };
    };

    systemd.services.epiviosi-wiki-reload = {
      description = "Rechargement de la bibliothèque EPIVÍOSI WIKI";
      serviceConfig.Type = "oneshot";
      script = ''
        sleep 2
        systemctl restart epiviosi-wiki.service
      '';
    };

    environment.etc."epiviosi/wiki/aide.html".source = ./assets/aide.html;

    environment.systemPackages = [
      pkgs.kiwix-tools
      pkgs.exfatprogs
      epiviosi-wiki-setup
      launcher
      desktopItem
    ];
  };
}
