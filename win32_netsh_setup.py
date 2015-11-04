
import sys, json, subprocess

def main():

    with open(sys.argv[1], "r") as f:
        config = json.load(f)

    if config["CFx"]["ip4_mask"] == 24:
        netmask = "255.255.255.0"
    elif config["CFx"]["ip4_mask"] == 16:
        netmask = "255.255.0.0"
    elif config["CFx"]["ip4_mask"] == 8:
        netmask = "255.0.0.0"

    if config["CFx"]["vpn_type"] == "SocialVPN":
        ip4 = config["AddressMapper"]["ip4"]
    elif config["CFx"]["vpn_type"] == "GroupVPN":
        ip4 = config["BaseTopologyManager"]["ip4"]
    else:
        ip4 = "172.31.0.100"
        
    subprocess.call(["netsh", "interface", "ip", "set", "address","ipop",
                     "static", ip4, netmask])
    subprocess.call(["netsh", "interface", "ipv4", "set", "subinterface",
                     "ipop", "mtu=1280", "store=persistent"])

if __name__ == "__main__":
    main()

