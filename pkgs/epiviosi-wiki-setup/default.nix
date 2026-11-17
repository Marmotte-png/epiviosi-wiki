{
  writeShellApplication,
  util-linux,
  gptfdisk,
  exfatprogs,
  gawk,
  gnugrep,
  gnused,
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
    gnused
    coreutils
    systemd
  ];
  text = builtins.readFile ./epiviosi-wiki-setup.sh;
}
