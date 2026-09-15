# Delete any conflicting connections
sudo nmcli connection delete enp2s0

# Recreate it explicitly tied to the device
sudo nmcli connection add \
  type ethernet \
  con-name enp2s0 \
  ifname enp2s0 \
  ipv4.method manual \
  ipv4.addresses 192.168.0.100/24 \
  ipv4.gateway 192.168.0.1 \
  ipv4.dns "8.8.8.8 8.8.4.4" \
  connection.autoconnect yes
