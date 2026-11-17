# epiviosi-wiki-fetch — télécharge des archives ZIM Kiwix (dernière version),
# avec reprise des téléchargements interrompus et vérification SHA-256.
#
# Usage : epiviosi-wiki-fetch [--dest DOSSIER] [--dry-run] [NOM...]
#   NOM       : archive sans date, ex. wikipedia_fr_all_maxi, wiktionary_fr_all_nopic.
#               Sans NOM : la sélection EPIVÍOSI (voir DEFAULT ci-dessous).
#   --dest    : dossier de destination (défaut : /wiki, la partition EPIV-WIKI).
#   --dry-run : affiche les fichiers et tailles, sans rien télécharger.

MIRROR="https://download.kiwix.org/zim"
DEFAULT=(wikipedia_fr_all_maxi wikipedia_en_all_mini)

die() { echo "Erreur : $*" >&2; exit 1; }
usage() { echo "Usage : epiviosi-wiki-fetch [--dest DOSSIER] [--dry-run] [NOM...]   (défaut : ${DEFAULT[*]})"; }
human() { numfmt --to=si --suffix=o "$1"; }

dest="/wiki" dry=0 names=()
while [ $# -gt 0 ]; do
  case "$1" in
    --dest) [ $# -ge 2 ] || die "--dest attend un dossier."; dest="$2"; shift ;;
    --dest=*) dest="${1#--dest=}" ;;
    --dry-run) dry=1 ;;
    -h|--help) usage; exit 0 ;;
    -*) die "option inconnue : $1" ;;
    *) names+=("${1%.zim}") ;;
  esac
  shift
done
[ ${#names[@]} -gt 0 ] || names=("${DEFAULT[@]}")
[ -d "$dest" ] || die "$dest n'existe pas (partition EPIV-WIKI absente ? sinon : --dest DOSSIER)."
[ "$dry" = 1 ] || [ -w "$dest" ] || die "pas le droit d'écrire dans $dest."

# Résolution : dernier fichier daté de chaque archive, et sa taille.
declare -A file size
total=0
for name in "${names[@]}"; do
  [[ "$name" =~ ^[a-z0-9]+_[a-z0-9_.-]+$ ]] || die "nom d'archive invalide : $name"
  category="${name%%_*}"
  index="$(curl -fsSL --retry 3 "$MIRROR/$category/")" || die "catalogue $MIRROR/$category/ inaccessible."
  f="$(grep -oE "\"${name}_[0-9]{4}-[0-9]{2}\.zim\"" <<<"$index" | tr -d '"' | sort -u | tail -n1)"
  [ -n "$f" ] || die "aucune archive « $name » sur $MIRROR/$category/."
  len="$(curl -fsSIL "$MIRROR/$category/$f" | tr -d '\r' | awk 'tolower($1)=="content-length:"{v=$2} END{print v}')"
  [ -n "$len" ] || die "taille de $f inconnue."
  file[$name]="$category/$f"; size[$name]="$len"
  have=0
  [ -f "$dest/$f.part" ] && have="$(stat -c %s "$dest/$f.part")"
  [ -f "$dest/$f" ] && have="$len"
  total=$((total + len - have))
  printf '  %-40s %8s%s\n' "$f" "$(human "$len")" "$([ -f "$dest/$f" ] && echo '  (déjà présent)')"
done

avail="$(df --output=avail -B1 "$dest" | tail -n1)"
echo "Reste à télécharger : $(human "$total") ; libre dans $dest : $(human "$avail")."
[ "$dry" = 1 ] && exit 0
[ "$total" -le "$avail" ] || die "espace insuffisant dans $dest."

for name in "${names[@]}"; do
  path="${file[$name]}"; f="${path#*/}"
  if [ -f "$dest/$f" ]; then
    echo "== $f : déjà présent."
    continue
  fi
  echo "== $f ($(human "${size[$name]}"))"
  # Extension .part : kiwix-serve ignore le fichier tant qu'il est incomplet.
  curl -fL --progress-bar -C - --retry 20 --retry-all-errors --retry-delay 10 \
       -o "$dest/$f.part" "$MIRROR/$path" \
    || die "téléchargement interrompu ; relancez la même commande pour reprendre."
  echo "Vérification SHA-256…"
  expected="$(curl -fsSL --retry 3 "$MIRROR/$path.sha256" | awk '{print $1}')"
  [ -n "$expected" ] || die "somme de contrôle de $f introuvable."
  actual="$(sha256sum "$dest/$f.part" | awk '{print $1}')"
  if [ "$actual" != "$expected" ]; then
    rm -f "$dest/$f.part"
    die "$f est corrompu (SHA-256 différent) ; fichier supprimé, relancez la commande."
  fi
  mv "$dest/$f.part" "$dest/$f"
  echo "$f : OK."
  for old in "$dest/${name}"_[0-9][0-9][0-9][0-9]-[0-9][0-9].zim; do
    [ -e "$old" ] && [ "$old" != "$dest/$f" ] && echo "  Ancienne version encore présente : $old (à supprimer si besoin)."
  done
done
echo "Terminé. Ouvrez « EPIVÍOSI WIKI » dans le menu."
