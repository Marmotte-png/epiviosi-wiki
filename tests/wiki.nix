# Test NixOS du module EPIVÍOSI WIKI : partition EPIV-WIKI branchée à chaud,
# ajout de ZIM pendant le fonctionnement, puis redémarrage avec la partition
# déjà présente.
{ pkgs, module }:
let
  zimFr = pkgs.fetchurl {
    url = "https://download.kiwix.org/zim/wikipedia/wikipedia_fr_climate-change_mini_2026-10.zim";
    hash = "sha256-746uQLU0on5x0QHcxBYn/3J1U9d6f4xloEOP2RPetl4=";
  };
  zimEn = pkgs.fetchurl {
    url = "https://download.kiwix.org/zim/wikipedia/wikipedia_en_ray-charles_nopic_2026-08.zim";
    hash = "sha256-WesrIzsfzdff1EZ5pRlQHb17d/vugKxGrZCleJlFnmI=";
  };
in
pkgs.testers.runNixOSTest {
  name = "epiviosi-wiki";

  nodes.machine =
    { lib, ... }:
    {
      imports = [ module ];
      # Options normalement déclarées par le socle EPIVÍOSI OS.
      options.epiviosi = {
        user = lib.mkOption {
          type = lib.types.str;
          default = "epiviosi";
        };
        wiki.enable = lib.mkEnableOption "EPIVÍOSI WIKI";
      };
      config = {
        epiviosi.wiki.enable = true;
        virtualisation.emptyDiskImages = [ 256 ];
        environment.systemPackages = [ pkgs.curl ];
      };
    };

  testScript = ''
    catalog = "curl -sf http://127.0.0.1:8080/catalog/v2/entries"

    def wait_catalog(pattern):
        try:
            machine.wait_until_succeeds(catalog + f" | grep -qi {pattern}", timeout=60)
        except Exception:
            print(machine.execute("systemctl list-units 'epiviosi-wiki*' wiki.mount --all --no-pager; "
                                  "journalctl -b --no-pager -u wiki.mount -u 'epiviosi-wiki*'")[1])
            raise

    machine.wait_for_unit("multi-user.target")

    with subtest("sans partition : rien n'est monté ni servi"):
        machine.fail("mountpoint -q /wiki")
        machine.fail("curl -sf http://127.0.0.1:8080/")

    with subtest("partition branchée à chaud, encore vide"):
        machine.succeed("mkfs.exfat -L EPIV-WIKI /dev/vdb")
        machine.succeed("udevadm trigger --action=add /dev/vdb && udevadm settle")
        machine.wait_for_unit("wiki.mount")
        machine.succeed("findmnt -no FSTYPE /wiki | grep -qx exfat")
        machine.sleep(3)
        machine.fail("curl -sf http://127.0.0.1:8080/")

    with subtest("premier ZIM : le serveur démarre"):
        machine.succeed("cp ${zimFr} /wiki/wikipedia_fr_climate-change_mini.zim")
        wait_catalog("climate")

    with subtest("deuxième ZIM : la bibliothèque est rechargée"):
        machine.succeed("mkdir -p /wiki/en && cp ${zimEn} /wiki/en/wikipedia_en_ray-charles_nopic.zim")
        wait_catalog("ray-charles")
        machine.succeed(catalog + " | grep -qi climate")

    with subtest("écoute uniquement en local"):
        # 4e colonne de ss : adresse locale d'écoute.
        local = machine.succeed("ss -ltnH 'sport = :8080' | awk '{print $4}'").split()
        assert local == ["127.0.0.1:8080"], local

    with subtest("redémarrage avec la partition déjà présente"):
        machine.shutdown()
        machine.start()
        machine.wait_for_unit("wiki.mount")
        wait_catalog("ray-charles")
        machine.succeed(catalog + " | grep -qi climate")
  '';
}
