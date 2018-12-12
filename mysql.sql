create database openvpn;
use openvpn;
create table vpnuser (
   name         char (100) not null,
   password     char (255) default null,
   active       int (10) not null default 1,
   primary key  (name)
   );
create table logtable (
   msg     char (254),
   user    char (100),
   pid     char (100),
   host    char (100),
   rhost   char (100),
   time    char (100)
   );
insert into vpnuser (name,password) values ('test1',password('test1'));
#grant all on openvpn.* to vpnadmin@'localhost' identified by 'vpnadminpwd';
#flush privileges;
