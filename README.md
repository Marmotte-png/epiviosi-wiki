# EPIVÍOSI WIKI

Wikipédia et autres archives ZIM hors-ligne pour [EPIVÍOSI OS](https://github.com/Marmotte-png/epiviosi),
servies par [Kiwix](https://kiwix.org) (`kiwix-serve`).

## Fonctionnement

- Les fichiers `.zim` sont trop gros pour l'ISO : ils vivent sur une partition **exFAT**
  étiquetée **`EPIV-WIKI`** (exFAT limite les étiquettes à 11 caractères).
- Dès qu'elle apparaît (au démarrage ou branchée à chaud), elle est montée sur `/wiki`.
  Le groupe `users` peut y écrire.
- `kiwix-serve` sert tous les `.zim` de `/wiki` et de ses sous-dossiers directs sur
  <http://127.0.0.1:8080>. Il écoute uniquement en local, bloque les liens externes (`--blockexternal`)
  et n'ouvre aucun port dans le pare-feu. Il tourne sous un utilisateur dynamique durci.
- Ajouter ou retirer un ZIM recharge la bibliothèque automatiquement. Une copie en cours
  est ignorée (`--skipInvalid`), puis prise en compte à la fin.
- Le lanceur **EPIVÍOSI WIKI** du menu ouvre la bibliothèque. S'il n'y a ni partition ni ZIM,
  il ouvre une page d'aide en français et en anglais.

## Préparer une clé (sélection EPIVÍOSI, clé de 128 Go)

La sélection par défaut est **Wikipédia FR complète avec images** (`wikipedia_fr_all_maxi`,
≈ 56 Go) et **l'introduction de chaque article de Wikipédia EN** (`wikipedia_en_all_mini`,
≈ 15 Go), soit ≈ 70 Go.

Dans EPIVÍOSI, sur la clé de démarrage :

```sh
sudo epiviosi-wiki-setup --size 75G     # partition EPIV-WIKI (sans --size : tout l'espace libre)
sudo epiviosi-persist-setup             # éventuellement, la persistance dans le reste (≈ 40 Go)
epiviosi-wiki-fetch                     # télécharge la sélection dans /wiki (connexion requise)
```

`epiviosi-wiki-fetch` prend toujours la dernière version publiée de chaque archive, vérifie
l'espace libre, reprend un téléchargement interrompu (relancer la même commande) et vérifie la
somme SHA-256 de chaque fichier. Autres usages :

```sh
epiviosi-wiki-fetch --dry-run                                   # tailles, sans télécharger
epiviosi-wiki-fetch wiktionary_fr_all_nopic                     # une autre archive Kiwix
nix run github:Marmotte-png/epiviosi-wiki#epiviosi-wiki-fetch -- --dest /media/…/EPIV-WIKI
                                                                # depuis un autre Linux
```

On peut aussi, depuis Windows, macOS ou Linux, formater une partition ou un disque en exFAT
avec le nom `EPIV-WIKI`, puis y copier des ZIM téléchargés sur
<https://download.kiwix.org/zim/wikipedia/>.

| Fichier | Contenu | Taille (catalogue Kiwix, nov. 2026) |
| --- | --- | --- |
| `wikipedia_fr_all_mini` | FR, introductions seulement | ≈ 6 Go |
| `wikipedia_fr_all_nopic` | FR, complet sans images | ≈ 13 Go |
| `wikipedia_fr_all_maxi` | FR, complet avec images | ≈ 56 Go |
| `wikipedia_en_all_mini` | EN, introductions seulement | ≈ 15 Go |
| `wikipedia_en_all_nopic` | EN, complet sans images | ≈ 53 Go |
| `wikipedia_en_all_maxi` | EN, complet avec images | ≈ 128 Go |

## Utilisation dans un flake

Le module implémente l'option `epiviosi.wiki.enable`, déclarée par le socle EPIVÍOSI OS :

```nix
inputs.epiviosi-wiki = {
  url = "github:Marmotte-png/epiviosi-wiki";
  inputs.nixpkgs.follows = "nixpkgs";
};
# …
modules = [ epiviosi-wiki.nixosModules.default { epiviosi.wiki.enable = true; } ];
```

## Tests

```sh
nix flake check                      # paquet + test en VM (nécessite KVM dans le bac à sable Nix)
# Sans KVM dans le bac à sable, lancer le test sous son propre utilisateur :
$(nix build --no-link --print-out-paths .#checks.x86_64-linux.vm.driver)/bin/nixos-test-driver
```

Le test monte une partition `EPIV-WIKI` à chaud, y ajoute deux petits ZIM réels, vérifie le
rechargement et l'écoute locale, puis redémarre la VM avec la partition déjà présente.

## Structure

| Chemin | Rôle |
| --- | --- |
| `module.nix` | Module NixOS : montage, `kiwix-serve`, rechargement, lanceur |
| `pkgs/epiviosi-wiki-setup/` | Outil `epiviosi-wiki-setup` (création de la partition) |
| `pkgs/epiviosi-wiki-fetch/` | Outil `epiviosi-wiki-fetch` (téléchargement vérifié des ZIM) |
| `assets/aide.html` | Page d'aide affichée sans ZIM |
| `tests/wiki.nix` | Test NixOS en VM |

## Licence

[Hippocratic License 2.1](LICENSE).
