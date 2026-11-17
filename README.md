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

## Préparer la partition

Dans EPIVÍOSI, sur la clé de démarrage :

```sh
sudo epiviosi-wiki-setup --size 60G     # ou sans --size : tout l'espace libre
sudo epiviosi-persist-setup             # éventuellement, la persistance dans le reste
```

On peut aussi, depuis Windows, macOS ou Linux, formater une partition ou un disque en exFAT
avec le nom `EPIV-WIKI`, puis y copier des ZIM téléchargés sur
<https://download.kiwix.org/zim/wikipedia/>.

| Fichier | Contenu | Taille approx. |
| --- | --- | --- |
| `wikipedia_fr_all_mini` | FR, introductions | ≈ 5 Go |
| `wikipedia_fr_all_nopic` | FR, sans images | ≈ 15 Go |
| `wikipedia_fr_all_maxi` | FR, complet | ≈ 35 Go |
| `wikipedia_en_all_nopic` | EN, sans images | ≈ 55 Go |
| `wikipedia_en_all_maxi` | EN, complet | ≈ 110 Go |

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
| `assets/aide.html` | Page d'aide affichée sans ZIM |
| `tests/wiki.nix` | Test NixOS en VM |

## Licence

[Hippocratic License 2.1](LICENSE).
