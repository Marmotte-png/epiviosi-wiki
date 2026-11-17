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

pttype="$(blkid -p -o value -s PTTYPE "$disk" 2>/dev/null || true)"
[ -n "$pttype" ] || die "$disk n'a pas de table de partitions."

echo "Disque cible : $disk ($pttype)"
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS "$disk"
echo
what="tout l'espace libre"; [ -n "$size" ] && what="$size"
echo "Une partition exFAT « $LABEL » ($what) va être créée dans l'espace libre de ce disque."
printf "Tapez OUI pour continuer : "
read -r answer
[ "$answer" = "OUI" ] || [ "$answer" = "YES" ] || die "annulé."

before="$(lsblk -lnpo NAME,TYPE "$disk" | awk '$2=="part"{print $1}' | sort)"

case "$pttype" in
  gpt)
    # Image hybride : l'en-tête GPT de secours est à la fin de l'image et non
    # à la fin du disque. On le déplace pour libérer l'espace restant.
    sgdisk -e "$disk" >/dev/null
    end="0"; [ -n "$size" ] && end="+$size"
    sgdisk -n "0:0:$end" -t "0:0700" -c "0:$LABEL" "$disk" >/dev/null || die "création de la partition impossible (espace libre insuffisant ?)."
    ;;
  dos)
    echo ",$size,07" | sfdisk --append --no-reread --wipe never "$disk" >/dev/null || die "création de la partition impossible (espace libre insuffisant ?)."
    ;;
  *)
    die "type de table de partitions non pris en charge : $pttype"
    ;;
esac

# Le disque est en cours d'utilisation (il porte /iso) : le noyau refuse de
# relire la table. On ajoute seulement les nouvelles partitions.
partx -a "$disk" 2>/dev/null || true
udevadm settle

after="$(lsblk -lnpo NAME,TYPE "$disk" | awk '$2=="part"{print $1}' | sort)"
part="$(comm -13 <(echo "$before") <(echo "$after") | head -n1)"
[ -n "$part" ] || die "nouvelle partition introuvable ; redémarrez puis relancez la commande."

mkfs.exfat -q -L "$LABEL" "$part" >/dev/null
udevadm settle

echo "Partition $part créée et montée sur /wiki."
echo "Copiez-y des fichiers .zim (https://download.kiwix.org/zim/wikipedia/),"
echo "puis ouvrez « EPIVÍOSI WIKI » dans le menu."
