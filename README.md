```
docker run --net=host --name freeswitch \
           -e SOUND_RATES=8000:16000 \
           -e SOUND_TYPES=music:en-us-callie \
           -v /etc/freeswitch1:/opt/freeswitch/etc/freeswitch \
           -v /data/call-app/recording:/opt/freeswitch/recordings \
           dolphin-freeswitch:0.1
```
