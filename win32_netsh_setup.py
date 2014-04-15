
import sys, json, subprocess

def main():

    with open(sys.argv[1], "r") as f:
        config = json.load(f)

    if config["ip4_mask"] == 24:
        netmask = "255.255.255.0"
    elif config["ip4_mask"] == 16:
        netmask = "255.255.0.0"
    elif config["ip4_mask"] == 8:
        netmask = "255.0.0.0"

    subprocess.call(["netsh", "interface", "ip", "set", "address","ipop",
                     "static", config["ip4"], netmask])
    subprocess.call(["netsh", "interface", "ipv4", "set", "subinterface",
                     "ipop", "mtu=1280", "store=persistent"])

if __name__ == "__main__":
    main()

