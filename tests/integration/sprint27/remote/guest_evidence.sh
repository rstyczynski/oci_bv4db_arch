set -o pipefail

echo "--- oracle-cloud-agent ---"
systemctl is-active oracle-cloud-agent || true
systemctl is-enabled oracle-cloud-agent || true
rpm -q oracle-cloud-agent device-mapper-multipath || true
echo "--- IMDS volume attachments ---"
curl -sS -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/volumeAttachments/ 2>&1 || true
echo
echo "--- block plugin log tail ---"
sudo tail -220 /var/log/oracle-cloud-agent/plugins/oci-blockautoconfig/oci-blockautoconfig.log 2>&1 || true
echo "--- iscsi sessions ---"
sudo iscsiadm -m session 2>&1 || true
echo "--- multipath -ll ---"
sudo multipath -ll 2>&1 || true
echo "--- multipathd paths ---"
sudo multipathd show paths 2>&1 || true
echo "--- multipath.conf ---"
sudo sed -n '1,220p' /etc/multipath.conf 2>&1 || true
echo "--- lsblk ---"
lsblk -o NAME,TYPE,SIZE,MODEL,WWN,FSTYPE,MOUNTPOINT 2>&1 || true
