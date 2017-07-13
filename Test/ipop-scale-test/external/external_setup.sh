XMPP_SERVER=$1
WORKSPACE="$HOME/workspace"
SCALE_TEST_DIR="ipop-scale-test"
SCALE_TEST_URL="https://github.com/cstapler/$SCALE_TEST_DIR"
CONTROLLERS_URL="https://github.com/ipop-project/Controllers"
TINCAN_URL="https://github.com/ipop-project/Tincan"
VISUALIZER="F"

mkdir -p $WORKSPACE
cd $WORKSPACE

if [ -d $WORKSPACE/$SCALE_TEST_DIR ] ; then
    rm -rf $WORKSPACE/$SCALE_TEST_DIR
fi

git clone $SCALE_TEST_URL
cd  "$WORKSPACE/$SCALE_TEST_DIR"

printf '%s\n%s\n%s\n%s\n' 'MODE switch-mode' 'MAX 2' 'MIN 1' 'NR_VNODES 2' > auto_config_scale.txt
cat auto_config_scale.txt
echo $XMPP_SERVER
./scale_test.sh configure true
./scale_test.sh containers-create 2 $CONTROLLERS_URL $TINCAN_URL $VISUALIZER true
./scale_test.sh ipop-run
