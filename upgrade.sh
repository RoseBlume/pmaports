version=0
echo "PostmarketOS upgrade script version: $version"

if ! apk --no-cache --allow-untrusted --force-missing-repos --no-network --no-interactive -X /etc/pmos_upgrader/apk_files/ upgrade -a; then
	pbsplash -e -s /usr/share/pbsplash/pmos-logo-text.svg -m "ERROR while upgrading postmarketOS" -b "Your device will reboot in 30 seconds. Logs are available at /etc/pmos_upgrader/upgrade.log."
	sleep 30
	reboot
	# make sure we do not run cleanup.py
	sleep 15
fi
cp /etc/apk/repositories /etc/pmos_upgrader/repositories_old
cp /etc/pmos_upgrader/repositories_new /etc/apk/repositories
echo "DONE!"
