{
  writeShellApplication,
  curl,
  coreutils,
  gnugrep,
  gawk,
}:
writeShellApplication {
  name = "epiviosi-wiki-fetch";
  runtimeInputs = [
    curl
    coreutils
    gnugrep
    gawk
  ];
  text = builtins.readFile ./epiviosi-wiki-fetch.sh;
}
