# epiviosi-wiki-setup — crée la partition exFAT EPIV-WIKI qui accueille les
# fichiers ZIM de Kiwix (lisible et inscriptible depuis Windows, macOS, Linux).
#
# Usage : sudo epiviosi-wiki-setup [--size TAILLE] [DISQUE]
#   --size TAILLE : taille de la partition (ex. 60G). Par défaut, tout
#                   l'espace libre. Pour garder de la place à la persistance,
#                   indiquez une taille puis lancez epiviosi-persist-setup.
#   DISQUE        : disque entier (ex. /dev/sdb). Par défaut, la clé USB qui a
#                   démarré EPIVÍOSI. Les partitions existantes ne sont pas
#                   modifiées.

# exFAT limite les étiquettes à 11 caractères.
LABEL="EPIV-WIKI"

die() { echo "Erreur : $*" >&2; exit 1; }
usage() { echo "Usage : sudo epiviosi-wiki-setup [--size TAILLE] [DISQUE]   (ex. --size 60G /dev/sdb)"; }

size="" disk=""
while [ $# -gt 0 ]; do
  case "$1" in
    --size) [ $# -ge 2 ] || die "--size attend une taille (ex. 60G)."; size="$2"; shift ;;
    --size=*) size="${1#--size=}" ;;
    -h|--help) usage; exit 0 ;;
    -*) die "option inconnue : $1" ;;
    *) disk="$1" ;;
  esac
  shift
done

if [ -n "$size" ]; then
  [[ "$size" =~ ^[0-9]+[KMGT]$ ]] || die "taille invalide : $size (ex. 500M, 60G, 1T)."
fi

[ "$(id -u)" -eq 0 ] || die "lancez cette commande avec sudo."

if [ -e "/dev/disk/by-label/$LABEL" ]; then
  echo "Une partition $LABEL existe déjà : $(readlink -f "/dev/disk/by-label/$LABEL")"
  exit 0
fi

if [ -z "$disk" ]; then
  src="$(findmnt -no SOURCE /iso 2>/dev/null || true)"
  [ -n "$src" ] || die "impossible de trouver le support de démarrage ; indiquez le disque (ex. /dev/sdb)."
  parent="$(lsblk -no PKNAME "$src" | head -n1)"
  if [ -n "$parent" ]; then disk="/dev/$parent"; else disk="$src"; fi
fi

[ -b "$disk" ] || die "$disk n'est pas un périphérique bloc."
[ "$(lsblk -dno TYPE "$disk")" = "disk" ] || die "$disk n'est pas un disque entier."
case "$(lsblk -dno TYPE,RO "$disk")" in
  *1) die "$disk est en lecture seule (CD/DVD ?). Le wiki nécessite une clé USB ou un disque." ;;
esac

# sfdisk lit la table elle-même : blkid -p ne conclut plus (« ambigu ») quand
# la signature iso9660 de l'image côtoie des partitions ajoutées.
pttype="$(sfdisk -d "$disk" 2>/dev/null | sed -n 's/^label: //p' || true)"
[ -n "$pttype" ] || die "$disk n'a pas de table de partitions."

echo "Disque cible : $disk ($pttype)"
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS "$disk"
echo
what="tout l'espace libre"; [ -n "$size" ] && what="$size"
echo "Une partition exFAT « $LABEL » ($what) va être créée dans l'espace libre de ce disque."
printf "Tapez OUI pour continuer : "
read -r answer
[ "$answer" = "OUI" ] || [ "$answer" = "YES" ] || die "annulé."

# Table MBR (cas de l'ISO EPIVÍOSI copiée sur une clé) : l'ISO occupe déjà
# 2 des 4 partitions principales (système et EFI) et sa partition système
# commence au secteur 0, ce qui trouble les outils de partitionnement. On
# ajoute une partition principale, puis on vérifie que les partitions
# existantes et l'identifiant du disque n'ont pas bougé ; sinon le secteur 0
# d'origine (table MBR) est remis en place.
ajout_partition_dos() {  # TAILLE (vide : tout l'espace) TYPE
  local avant apres mbr err
  avant="$(sfdisk -d "$disk" | grep -E '^(label-id|[^ ]+ : start=)')"
  [ "$(grep -c ' : start=' <<<"$avant")" -lt 4 ] \
    || die "4 partitions principales déjà présentes : plus de place (table MBR)."
  mbr="$(mktemp)"
  dd if="$disk" of="$mbr" bs=512 count=1 status=none
  err="$(echo ",$1,$2" | sfdisk --append --no-reread --wipe never "$disk" 2>&1 >/dev/null)" \
    || { rm -f "$mbr"
         if grep -q "No free sectors" <<<"$err"; then
           die "plus d'espace libre sur le disque. La persistance (epiviosi-persist-setup sans --size) prend tout l'espace restant : créez le wiki avant elle."
         fi
         die "création de la partition impossible : $(tail -n1 <<<"$err")"; }
  apres="$(sfdisk -d "$disk" | grep -E '^(label-id|[^ ]+ : start=)')"
  if [ "$(grep -vxFf <(printf '%s\n' "$apres") <<<"$avant" || true)" != "" ]; then
    dd if="$mbr" of="$disk" bs=512 count=1 conv=notrunc,fsync status=none
    rm -f "$mbr"
    die "la table de partitions a été modifiée de façon inattendue ; table d'origine restaurée."
  fi
  rm -f "$mbr"
}

# Entrées de la table de partitions (une ligne par partition).
entrees() { sfdisk -d "$disk" | grep -E '^[^ ]+ : start=' || true; }

table_avant="$(entrees)"

case "$pttype" in
  gpt)
    # Disque GPT : l'en-tête de secours doit être à la fin du disque
    # (s'il a été copié d'une image plus petite). On le déplace.
    sgdisk -e "$disk" >/dev/null
    end="0"; [ -n "$size" ] && end="+$size"
    sgdisk -n "0:0:$end" -t "0:0700" -c "0:$LABEL" "$disk" >/dev/null || die "création de la partition impossible (espace libre insuffisant ?)."
    ;;
  dos)
    ajout_partition_dos "$size" 07
    ;;
  *)
    die "type de table de partitions non pris en charge : $pttype"
    ;;
esac

# La nouvelle partition est la seule entrée de la table qui n'existait pas
# avant : on ne se fie pas à ce que le noyau affiche (sur l'image ISO, sa
# partition système, qui commence au secteur 0, peut n'apparaître qu'après coup
# et serait prise à tort pour la nouvelle).
part="$(entrees | grep -vxFf <([ -n "$table_avant" ] && printf '%s\n' "$table_avant") | sed -nE 's/^([^ ]+) : .*/\1/p' | head -n1 || true)"
[ -n "$part" ] || die "nouvelle partition introuvable dans la table."

# Le disque est peut-être en cours d'utilisation (il porte /iso) : le noyau
# refuse alors de relire la table. On ajoute seulement les partitions qui lui
# manquent, sans toucher à celles qui existent.
partx -a "$disk" 2>/dev/null || true
udevadm settle
for _ in 1 2 3 4 5 6 7 8 9 10; do
  [ -b "$part" ] && break
  sleep 1
done
[ -b "$part" ] || die "la partition $part n'apparaît pas ; redémarrez puis relancez la commande."

mkfs.exfat -q -L "$LABEL" "$part" >/dev/null
udevadm settle

echo "Partition $part créée et montée sur /wiki."
echo "Copiez-y des fichiers .zim (https://download.kiwix.org/zim/wikipedia/),"
echo "puis ouvrez « EPIVÍOSI WIKI » dans le menu."
