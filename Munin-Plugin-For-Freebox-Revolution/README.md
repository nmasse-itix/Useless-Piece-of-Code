# The Munin plugin for the Freebox Revolution RRD data

## Purpose

Although the new Freebox provides some nive graphs about its usage, it could be useful to have everything consolidated in Munin. 

_"Munin is a networked resource monitoring tool that can help analyze resource trends and "what just happened to kill our performance?" problems. "_

For more information, see http://munin-monitoring.org and http://www.free.fr/adsl/freebox-revolution.html.

## Installation

First of all, you must have a working installation of Munin. See http://munin-monitoring.org/wiki. 

```
cd /usr/local/src
git clone https://github.com/nmasse-itix/Useless-Piece-of-Code.git useless
```

## Configuration

To be able to use the Freebox API, you need to get a valid AppToken. To do so, run the "get-app-token" script. 

```
cd /usr/local/src/useless/Munin-Plugin-For-Freebox-Revolution
./get-app-token
```

The script uses the Freebox API to request an AppToken and keeps polling until the request is approved or denied. **You have to accept the request on the front LCD display of your Freebox**. 

You should get the following output: 

```
APPTOKEN is '3TZzUgo9tTYk02ATOcRRU4qjMwo5bWYRq4is+uytrP4/yJpta230MhJiZ7z94ai/'

Now you have to approve that apptoken on the Freebox front display !!!

N: 1 STATUS: pending
N: 2 STATUS: pending
N: 3 STATUS: pending
N: 4 STATUS: granted
Final status is 'granted'

Congratulation ! You have a valid AppToken.

You can store the AppToken in /etc/munin/plugin-conf.d/fb

  [fb_*]
  env.FB_AppToken 3TZzUgo9tTYk02ATOcRRU4qjMwo5bWYRq4is+uytrP4/yJpta230MhJiZ7z94ai/


Then, you will have to go on the FreeBox web interface to give the 'settings configuration' privileges to that new app token.
```

As asked, create a new file named "/etc/munin/plugin-conf.d/fb" with the following content: 
```
[fb_*]
env.FB_AppToken <put your apptoken here>
```

Now, connect to http://mafreebox.freebox.fr, login and go to *Paramètres de la Freebox* > *Gestion des accès* > *Applications*. 
Edit the new Munin application and enable *Modification des règlages de la Freebox*. Click *OK*.

## Register the plugin

```
cd /etc/munin/plugins
for i in fb_dsl_rate fb_dsl_snr fb_fan fb_net fb_temp; do ln -s /usr/local/src/useless/Munin-Plugin-For-Freebox-Revolution/fb_ fb_$i; done
```
## Test 

Run *munin-run* to test the new plugin.

```
munin-run fb_temp
```

If everything is correct, you should get something like this:
```
temp_sw.value 44
temp_cpub.value 66
temp_hdd.value 40
temp_cpum.value 53
```

## Restart munin-node

Depending on your distribution, it may be 
```
/etc/init.d/munin-node restart
```
or :
```
systemctl restart munin-node
```

## The final touch

Wait a few hours until munin collects enough data and enjoy !
