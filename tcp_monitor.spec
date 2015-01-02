# Mode: vim, tabstop=2; softtabstop=2; shiftwidth=2; 
Summary       : An "established-TCP-connection"-monitoring-tool
Name          : tcp_monitor
Version       : 1.4
Release       : 1%{?dist}
Group         : Applications/System
URL           : https://github.com/patchon/%{name}/
Source0       : https://github.com/patchon/%{name}/archive/%{name}-%{version}.tar.gz
License       : GPLv2+ and Public Domain
BuildArch     : noarch
Requires      : coreutils
Requires      : iproute
Requires      : ncurses 
Requires      : sed
BuildRequires : coreutils
BuildRequires : grep
BuildRequires : telnet 

%description
This package contains a small tool for monitoring established TCP-connections. 
It comes bundled with a systemd-unit for enabling the tool at boot as a service.

%prep
# The weird naming convention here is because of github and how it names 
# the archives, 
%setup -q -n %{name}-%{name}-%{version}


%build
# Execute our testing suite to make sure everything is fine. 
# You could get rid of the output here if it's getting annoying in the long run,
# as long as our exit codes are fine, we should be fine. 
sh test_pmartinsson.sh -v  # &>/dev/null

%install
# Create our structure, and install files below, 
mkdir -p                        \
    %{buildroot}%{_bindir}      \
    %{buildroot}%{_mandir}/man1 \
    %{buildroot}%{_sysconfdir}  \
    %{buildroot}%{_unitdir}

# Executable, manfile, and config-file
install -m755 tcp_monitor.sh      %{buildroot}%{_bindir}
install -m644 tcp_monitor.sh.1.gz %{buildroot}%{_mandir}/man1
install -m644 tcpmonitor.conf     %{buildroot}%{_sysconfdir}
install -m644 tcp_monitor.service %{buildroot}%{_unitdir}

# We do not use the inbuilt systemd macros here, since we don't 
# want to enable this service as default by the "systemd/fedora-prefix-strategy".

%post
# Just reload systemd to make it pickup our unit, 
if [ $1 -eq 1 ]; then 
  /bin/systemctl daemon-reload &> /dev/null || :
fi

%preun
if [ $1 -eq 0 ] ; then
  # At package removal, test if user has enabled our service, if so, disable it 
  # and stop it. We stop it even if it's not running, thats fine by systemd. 
  if /bin/systemctl is-enabled tcp_monitor.service &> /dev/null; then
    /bin/systemctl stop tcp_monitor.service &> /dev/null  || :
    /bin/systemctl disable tcp_monitor.service &> /dev/null || :
  fi
fi

%postun
if [ $1 -ge 1 ] ; then 
  # If package gets updated, restart our service. 
  /bin/systemctl try-restart tcp_monitor.service &> /dev/null || :
fi

%files
%{!?_licensedir:%global license %%doc}
%license COPYING
%doc README.md
%{_mandir}/man1/tcp_monitor.sh.1.gz
%config(noreplace) %{_sysconfdir}/tcpmonitor.conf
%{_bindir}/tcp_monitor.sh
%{_unitdir}/tcp_monitor.service

%changelog
* Fri Jan 02 2015 Patrik Martinsson <martinsson.patrik@gmail.com> - 1.4-1
- Again with the manpage...
* Fri Jan 02 2015 Patrik Martinsson <martinsson.patrik@gmail.com> - 1.3-1
- Fixing some bugs with the os-detection, and improvementes regarding
  the screen restoring.
* Fri Jan 02 2015 Patrik Martinsson <martinsson.patrik@gmail.com> - 1.2-1
- Renaming manpage due to rpmlint-complaint.
* Fri Jan 02 2015 Patrik Martinsson <martinsson.patrik@gmail.com> - 1.1-1
- Adding the COPYING-file to package.
* Fri Jan 02 2015 Patrik Martinsson <martinsson.patrik@gmail.com> - 1.0-1
- Initial release for tcp_monitor.
