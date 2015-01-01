## Introduction 
This is the README of tcp_monitor. 

In this README you will find information about how tcp_monitor is built and why 
that specific method was used. 


## Main purpose of tcp_monitor 

- List information about established tcp-connections (local-addr:port, 
  remote-addr:port, duration, pid) in an interface.

- The refresh rate should be configurable.

- The amount of times the interface should be updated should be configurable. 

- The output should be on **stdout** by default, but configurable to a file. 

- The options should be specified on the command-line or read in by a 
  configuration-file (specified by the -c-flag) 


## Methods used 
- Use the **ss-tool** to get information about established tcp-connections. 
- Use **tput/printf/echo** to present the information to the user in a column-
  based output. 
- Using **stat** on the socket to get the duration of the socket. 


#### Why ss : 
- I used ss for a couple of reasons, but mainly because it has most of the 
  information that we need. The only piece it doesn't got is the duration
  of the connection (read more about that later). 
  I **did not** choose to manually parse **/proc/net/tcp/** for exactly the 
  reason given above - there's no need to rewrite a thing like that, when we 
  already have an excellent tool for it. You could of course argue that parsing 
  **/proc/net/tcp/** is more portable than the **ss-tool**, and you may have a 
  point, however it should be noted that the **ss-tool** comes with the 
  **iproute-package** (on fedora/rhel) which is **always** installed by default.
  I do not really now how the tool is distributed by other distros, however 
  again, this task was for fedora.


#### Why tput/echo/printf :
- First off, using builtin's **echo** and **printf** doesn't really need an 
  explanation, they are there, use them. No need for using anything else. 
  Since you can format you output with **printf** it becomes really handy, 
  **echo** is simple to use, but there is rarely a reason not to use **printf**,
  my personal thought on the matter is something like, '*use whatever you want 
  as long as it prints the way you want'*. 


- Using *tput* to calculate the widht/height of the terminal is extremely
  convenient, also saving the current state of the terminal and restoring it is 
  nice feature, as well as moving the cursor to a specific row and clearing it
  (instead of clearing the whole screen). With that being said, we are actually
  clearing the *whole screen* when doing updates, however when we show the user 
  a simple warning we make use of the moving-cursor-clear-line-technique. 


#### Why using stat :  

- Well, there isn't *really* a good way of determining the duration of the 
  socket's lifetime - if you don't choose to actually log when it was created. 
  There are some methods that seems to be preferred when doing this, namely 
  using the '*audit-system*' or the '*contrack-system*' (at least that I can 
  seem to find). However, both of them has some disadvantages. Below are some 
  thoughts on the matter, ie. "how it *could* be done", 
  
  - Setting up an "audit-rule" when we install the rpm, that will log all 
    creation of sockets. This is bad though, probably because of a lot more 
    reasons than these two, but these are the ones that directly comes to mind. 
    - Maybe the user doesn't even use the auditd, then we need to make sure that
      it's turned on and working. 
    - Setting up a rule of this kind in the rpm would mean that we would log all
      socket creations until the user uninstalls the rpm, this is most probably
      something we *don't want*. We could use try to do this when the script is 
      started, but that in turn would mean that we would need to run this as 
      root. 
    
  - Setting up the **nf_conntrack module** (it's loaded by default, but we need 
    to verify it) and either use **conntrack** (userspace tool) or manually 
    parse the information to get the information we need. Neither of those two 
    methos are particular practical and require root-privileges. We also need to
    make sure that '**nf_conntrack_timestamp**' is set to '**1**'. As discussed 
    above, we could do it in the rpm, or in the script, but we will still have 
    the same issues. 

 **So, basically these approaches seems rather 'hacky' and over-complicated to
   me.** 
   
   Read more under '''Known limitations''' about this. 

 
## Known Limitations

#### Output from ss :  
 
 Basically we are covered pretty good here, but there are a few cases we don't 
 handle. 
 
* I think there is a special output if we have se-linux enabled, this is 
  not handled today. 

* We don't handle the case when multiple pid's are using the same sockets, 
  this wouldn't be to hard to implement though. 

#### Gui :  
 
 The way that the gui is painted is by simply printing the text on the screen 
 with **echo/printf**. The printed data will stay there until we have new data 
 to print, and when we do, we will clear the screen with '**tput clear**' and 
 print the data again. This works fairly well, it can however produce some 
 '*flickering*' sometimes, this is most probably depending on your hardware and 
 what your computer is doing at the time of the printing. 

 A problem with printing data in this way is that, it will be rather messy if 
 the lines to print are more than you have lines in your terminal. The issue is
 basically that we will start to scroll every time we get to that limit.
 
 Imagine if you have a refresh every second, and you needed to print let's say 
 100 lines and your terminal only holds 50. Then we will print 50 lines, then
 another 50 and scroll to the bottom - wait one second, clear the screen and
 repeat. This is most probably a very annoying behaviour, and something that the
 end-user wouldn't like to much. 

 Now, one way to resolve this is to a quite advance "printing routine", 
 
 - Maybe one where we keep track of everything that's is suppose to get updated
   on the screen, and only update those lines. We simply remove the sockets that
   are gone, update the duration on those who are still there, and add new ones 
   at the bottom (or top if preferable) of the screen (no matter if they are in 
   "the visible area" of terminal or not). Now, this seems like a good approach,
   however I honestly don't know how to write a thing like that within this 
   time-frame, with that being said, I know I would be able to do it under the 
   right conditions. 

 I took another approach were I simply '*cut off*' the lines that doesn't fit 
 the terminal, and at the end of the screen I tell the user to use -f instead. 
 Now this may not be the best way of doing it, however I think that it is 
 'a good enough' approach for this task - please correct me if I'm wrong. 


#### Using stat to get duration : 

The main issue with using stat on an **fd** under **/proc/$pid** is that it 
doesn't necessarily (and maybe even most probably) give you the time when the 
**fd** was created; **it will give you the time when it was first accessed, 
which will most probably differ from the time the socket was created**. You can
test this very easy by doing a '**nc localhost 22**' (*you need an ssh-daemon 
listening on port 22 of course*), and wait a few seconds, and then do a **stat**
on that **nc**'s socket, you will then see that the modify/change-times are set
to the **time right now**, not the times a few seconds ago when the socket 
*actually* was created. 

This is unfortunately a price we have to pay when using this method - *however*
if you are really interested in the duration-times of a socket, you can enable 
the provided systemd-service to start tcp_monitor.sh at boot, which will then 
stat every socket every second from boot (or at least quite early in the boot),
and from that we get a pretty accurate duration (maybe a second of if we are 
unlucky), the output is then appended to /var/log/tcp_monitor. Doing this, we 
will get the same behaviour as the other methods discussed. 


## Test cases for the tcp_monitor, 
The script **test_pmartinsson.sh** will run **9** test cases against the 
tcp_monitor, it will validate the following, 

* Test command-line options with invalid values.

* Test command-line options with values out of bound.

* Test command-line options with missing values within/without quotes. 

* Test command-line options with invalid values within/without quotes and 
  spaces. 

* Test valid command line-options for output-file where directory does't exist
  and should be created.

* Test valid command line-options for output-file wheredirectory does't exist 
  and shouldn't be created.

* Test valid command line-options for config-file where the config-file contains
  both valid and invalid values.

* Test valid command line-options for config-file where the config-file contains
  only valid values.

* Test valid command line-options for config-file where the config-file contains
  only valid options that are overridden by the command line-options.

* A regression test that will test that we got the expected output from ss. This
  is done in two steps, firstly we do an **nc google.com 80**, secondly we 
  verify the output in **tcp_monitor** is as expected. I call this a regression-
  test since it should tell us if anything is out of order, it doesn't 
  necessarily tells us *what is broken*, but it will at least tell us that 
  *something is broken* and we need to fix it.
 

## Improvements / Ideas 

#### For the tcp_monitor itself : 
- A better handling of the "gui-printing", 
- Maybe test another approach on grabbing the socket creation-time, 
- Handle multiple pids using the same socket.
- Make new tcp-connections appear at the top of the list, 
- Convert seconds into something more readable if it gets above a minute, 
- Resolve addresses instead of using ip's (now this is an interesting task,
  since resolving an address could potentially take a lot longer then the 
  refresh rate the user has set), 
- Handle selinux (I'm not really sure if we do this today), 
- Add version-flag 
- Set trap for various stuff, like sorting order, quitting etc. 


#### Coding wise :
- There's probably a few bugs here and there that could be fixed/improved in the
  code.
- We could add checks in each function that will determine if the call to the 
  function is done with the right parameters etc. 
- I think the naming-convention is pretty good, but it could possible be 
  improved. 


## Last thoughts  

Reading up on some of the '*best practises*' in bash-programming it is often 
suggested that one should be using the flags '**pipefail and errexit**'. 
However I don't necessarily agree, I do understand why people use them, I 
just don't see why I should. I tend to be extremely careful when 'calling 
external' applications, I always check the return-code of the called application
and I always check so I get the expected output. A side effect of using the 
mentioned flags is that you cant create your own 'custom error-message' to 
display to the user (or at least I'm unaware of how to do it) when something 
goes wrong. Your script will simply die with an error-message from bash. 

As I said, I do understand why the flags are there and recommended in some
cases, however I don't think they apply very well my type of coding. 
