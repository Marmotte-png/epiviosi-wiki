{
  writeShellApplication,
  util-linux,
  gptfdisk,
  exfatprogs,
  gawk,
  gnugrep,
  coreutils,
  systemd,
}:
writeShellApplication {
  name = "epiviosi-wiki-setup";
  runtimeInputs = [
    util-linux
    gptfdisk
    exfatprogs
    gawk
    gnugrep
    coreutils
    systemd
  ];
  text = builtins.readFile ./epiviosi-wiki-setup.sh;
}
