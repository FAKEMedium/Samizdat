-- This is an older MariaDB database we're migrating away from
-- A lot of classes in this application are still using it
-- Their corresponding scripts are oldstyle Perl CGI, not present in this app.

-- phpMyAdmin SQL Dump
-- version 5.2.2
-- https://www.phpmyadmin.net/
--
-- Host: localhost
-- Generation Time: Oct 13, 2025 at 06:39 PM
-- Server version: 11.4.7-MariaDB-log
-- PHP Version: 8.3.23

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `system3`
--

-- --------------------------------------------------------

--
-- Table structure for table `Account`
--

CREATE TABLE `Account` (
                         `accountPK` int(10) UNSIGNED NOT NULL,
  `datestamp` date NOT NULL DEFAULT '0000-00-00',
  `status` tinyint(3) UNSIGNED NOT NULL DEFAULT 0,
  `accountName` varchar(255) NOT NULL DEFAULT '',
  `email` varchar(255) NOT NULL DEFAULT '',
  `org_nr` varchar(11) DEFAULT NULL,
  `address` varchar(255) DEFAULT NULL,
  `zip` int(10) UNSIGNED DEFAULT NULL,
  `city` varchar(50) DEFAULT NULL,
  `country` varchar(50) DEFAULT NULL,
  `phone1` varchar(50) DEFAULT NULL,
  `phone2` varchar(50) DEFAULT NULL,
  `fax` varchar(50) DEFAULT NULL,
  `memo` varchar(255) DEFAULT NULL
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `accountbook`
--

CREATE TABLE `accountbook` (
                             `id` int(11) UNSIGNED NOT NULL,
  `customerid` int(11) UNSIGNED NOT NULL DEFAULT 0,
  `accountnumber` int(11) UNSIGNED NOT NULL DEFAULT 0,
  `accounttype` enum('kredit','debet') NOT NULL DEFAULT 'kredit',
  `summa` float NOT NULL DEFAULT 0,
  `invoiceid` int(11) UNSIGNED NOT NULL DEFAULT 0,
  `event` enum('fakturera','bokfora','makulera') NOT NULL DEFAULT 'fakturera'
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `accountchart`
--

CREATE TABLE `accountchart` (
                              `accountnumber` int(11) NOT NULL DEFAULT 0,
  `accountname` char(127) NOT NULL DEFAULT ''
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `AllSessions`
--

CREATE TABLE `AllSessions` (
                             `id` int(11) UNSIGNED NOT NULL,
  `username` varchar(191) NOT NULL DEFAULT '',
  `remote_host` varchar(191) NOT NULL DEFAULT '',
  `login_time` datetime NOT NULL DEFAULT '0000-00-00 00:00:00'
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `certs`
--

CREATE TABLE `certs` (
                       `certid` int(11) NOT NULL,
  `certvalue` mediumtext NOT NULL,
  `notafter` datetime DEFAULT NULL,
  `filename` char(255) NOT NULL DEFAULT '',
  `hash` char(10) NOT NULL DEFAULT '',
  `origintype` enum('ownca','letsencrypt','') NOT NULL DEFAULT 'ownca'
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `contact`
--

CREATE TABLE `contact` (
                         `contactid` int(10) UNSIGNED NOT NULL,
  `typeId` int(10) UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Kontakttyp',
  `customerid` int(10) UNSIGNED NOT NULL,
  `name` varchar(255) NOT NULL DEFAULT '',
  `org` varchar(255) DEFAULT '',
  `street` varchar(255) NOT NULL DEFAULT '',
  `city` varchar(128) NOT NULL DEFAULT '',
  `pc` varchar(16) NOT NULL DEFAULT '',
  `sp` varchar(255) DEFAULT '' COMMENT 'Stat eller provins',
  `cc` varchar(2) NOT NULL COMMENT 'Landskod',
  `voice` varchar(64) NOT NULL DEFAULT '',
  `fax` varchar(64) DEFAULT '',
  `email` varchar(128) NOT NULL DEFAULT '',
  `orgno` varchar(128) NOT NULL DEFAULT '',
  `vatno` varchar(128) DEFAULT ''
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `contactTypes`
--

CREATE TABLE `contactTypes` (
                              `typeId` int(10) UNSIGNED NOT NULL,
  `typeName` varchar(128) NOT NULL
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci COMMENT='Kontakttyper';

-- --------------------------------------------------------

--
-- Table structure for table `countryinfo`
--

CREATE TABLE `countryinfo` (
                             `iso` char(2) NOT NULL,
  `iso3` char(3) NOT NULL,
  `ISONumeric` smallint(5) UNSIGNED NOT NULL,
  `name_en` varchar(255) NOT NULL,
  `name_sv` varchar(255) NOT NULL,
  `continent` enum('EU','NA','SA','AS','AF','OC','AN') NOT NULL,
  `tld` char(3) NOT NULL,
  `CurrencyCode` varchar(5) NOT NULL,
  `CurrencyName` varchar(32) NOT NULL,
  `Phone` varchar(12) NOT NULL,
  `PostalCodeFormat` varchar(255) NOT NULL,
  `PostalCodeRegex` varchar(255) NOT NULL,
  `Languages` varchar(255) NOT NULL,
  `geonameid` int(10) UNSIGNED NOT NULL,
  `eu` tinyint(1) NOT NULL DEFAULT 0 COMMENT 'Medlem i EU',
  `flag_svg` mediumtext NOT NULL,
  `flag_base64` mediumtext NOT NULL
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci COMMENT='http://download.geonames.org/export/dump/countryInfo.txt';

-- --------------------------------------------------------

--
-- Table structure for table `customer`
--

CREATE TABLE `customer` (
                          `customerid` int(11) UNSIGNED NOT NULL,
  `public` tinyint(3) UNSIGNED NOT NULL DEFAULT 0,
  `company` varchar(191) NOT NULL DEFAULT '',
  `firstname` varchar(191) NOT NULL DEFAULT '',
  `lastname` varchar(191) NOT NULL DEFAULT '',
  `address` varchar(191) NOT NULL DEFAULT '',
  `zip` varchar(12) NOT NULL DEFAULT '',
  `city` varchar(191) NOT NULL DEFAULT '',
  `contactemail` varchar(191) NOT NULL DEFAULT '',
  `country` char(2) NOT NULL DEFAULT 'SE',
  `orgno` varchar(20) NOT NULL DEFAULT '',
  `vatno` varchar(25) NOT NULL,
  `phone1` varchar(25) NOT NULL DEFAULT '',
  `phone2` varchar(25) NOT NULL DEFAULT '',
  `active` int(11) NOT NULL DEFAULT 1,
  `created` datetime DEFAULT NULL,
  `creator` varchar(191) NOT NULL DEFAULT '',
  `updated` datetime DEFAULT NULL,
  `updater` varchar(191) NOT NULL DEFAULT '',
  `freetext` mediumtext NOT NULL,
  `reference` varchar(191) NOT NULL DEFAULT '',
  `recommendedby` varchar(191) NOT NULL DEFAULT '',
  `period` enum('monthly','quarterly','halfyear','yearly','nopay') NOT NULL DEFAULT 'quarterly',
  `currency` enum('sek','nok','dkk','eur','gbp','usd') NOT NULL DEFAULT 'sek',
  `invoicetype` enum('email','snailmail') NOT NULL DEFAULT 'email',
  `vat` float NOT NULL DEFAULT 0.25,
  `snapbackonly` tinyint(3) UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Kund som enbart köper snapback',
  `newsletter` tinyint(3) UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Nyhetsbrev för webbhotellkunder',
  `lang` varchar(6) NOT NULL DEFAULT 'sv_SE' COMMENT 'Språkval för gettext',
  `moss` tinyint(3) UNSIGNED NOT NULL DEFAULT 0,
  `trust` enum('blocked','normal','trusted') NOT NULL DEFAULT 'normal' COMMENT 'Ekonomisk bedömning',
  `rabatt` tinyint(1) NOT NULL DEFAULT 0,
  `kompispris` tinyint(1) NOT NULL DEFAULT 0,
  `billingemail` varchar(191) NOT NULL DEFAULT '',
  `billingaddress` varchar(191) NOT NULL DEFAULT '',
  `billingzip` varchar(12) NOT NULL DEFAULT '',
  `billingcity` varchar(191) NOT NULL DEFAULT '',
  `billingcountry` char(2) NOT NULL DEFAULT '',
  `billinglang` varchar(6) NOT NULL DEFAULT '',
  `lastcheck` date DEFAULT NULL COMMENT 'Senaste adresscheck'
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `databases`
--

CREATE TABLE `databases` (
                           `databaseid` int(11) NOT NULL,
  `databasename` char(255) NOT NULL DEFAULT '',
  `created` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `creator` char(255) NOT NULL DEFAULT '',
  `updated` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `updater` char(255) NOT NULL DEFAULT '',
  `customerid` int(11) NOT NULL DEFAULT 0,
  `db_usage` bigint(20) NOT NULL DEFAULT 0,
  `pass` char(255) NOT NULL DEFAULT '',
  `username` char(31) NOT NULL DEFAULT ''
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `defaultDNS`
--

CREATE TABLE `defaultDNS` (
                            `userlogin` varchar(15) NOT NULL COMMENT 'Kopplat till snapusers',
  `dns` varchar(191) NOT NULL COMMENT 'DNS-server',
  `customerid` int(10) UNSIGNED NOT NULL DEFAULT 0
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci COMMENT='Standard-DNS:er';

-- --------------------------------------------------------

--
-- Table structure for table `dnsDomain`
--

CREATE TABLE `dnsDomain` (
                           `domainname` varchar(191) NOT NULL,
  `customerid` int(10) UNSIGNED NOT NULL DEFAULT 0
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci COMMENT='Domäner vi servar med DNS';

-- --------------------------------------------------------

--
-- Table structure for table `dnssec`
--

CREATE TABLE `dnssec` (
                        `id` int(10) UNSIGNED NOT NULL,
  `customerid` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `domainid` int(10) UNSIGNED NOT NULL,
  `created` datetime NOT NULL DEFAULT current_timestamp(),
  `updated` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `keytag` varchar(191) NOT NULL
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `domain`
--

CREATE TABLE `domain` (
                        `domainid` int(10) UNSIGNED NOT NULL,
  `domainname` varchar(191) NOT NULL DEFAULT '',
  `customerid` int(11) UNSIGNED NOT NULL DEFAULT 0,
  `registrantid` varchar(191) NOT NULL DEFAULT '',
  `curexpiry` date NOT NULL DEFAULT '2099-12-31',
  `deletedate` date DEFAULT NULL,
  `pw` varchar(191) NOT NULL DEFAULT '',
  `registryid` tinyint(3) UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Vilken registrar',
  `updated` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `updater` varchar(191) NOT NULL DEFAULT '',
  `created` datetime NOT NULL DEFAULT current_timestamp(),
  `creator` varchar(191) NOT NULL DEFAULT '',
  `active` tinyint(3) UNSIGNED NOT NULL DEFAULT 1,
  `alias` int(11) NOT NULL DEFAULT 0,
  `period` varchar(191) NOT NULL DEFAULT '1y',
  `dontrenew` tinyint(4) NOT NULL DEFAULT 0 COMMENT 'Förnyas inte',
  `dns` tinyint(3) UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Körs dns hos oss?',
  `dnssec` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `udrp` tinyint(3) UNSIGNED NOT NULL DEFAULT 0
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci COMMENT='Domännamn vi hanterar';

-- --------------------------------------------------------

--
-- Table structure for table `Domain`
--

CREATE TABLE `Domain` (
                        `domainPK` int(10) UNSIGNED NOT NULL,
  `status` tinyint(3) UNSIGNED NOT NULL DEFAULT 0,
  `domainName` varchar(191) NOT NULL DEFAULT '',
  `passwd` varchar(191) NOT NULL DEFAULT '',
  `passwdargon2` varchar(191) NOT NULL DEFAULT '',
  `UID` tinyint(3) UNSIGNED DEFAULT 0,
  `gid` tinyint(3) UNSIGNED DEFAULT 0,
  `home` varchar(191) NOT NULL DEFAULT '',
  `active` tinyint(4) NOT NULL DEFAULT 1,
  `customerid` int(11) NOT NULL DEFAULT 0,
  `created` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `updated` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `shell` varchar(191) NOT NULL DEFAULT '/bin/ftponly',
  `host` varchar(191) NOT NULL DEFAULT 'kronos',
  `server` int(10) UNSIGNED NOT NULL DEFAULT 1,
  `hasweb` tinyint(4) NOT NULL DEFAULT 1,
  `serverAdmin` varchar(191) NOT NULL DEFAULT 'roomservice@rymdweb.com',
  `sslornot` enum('yes','no','both') NOT NULL DEFAULT 'no',
  `certid` int(11) NOT NULL DEFAULT 0,
  `ipold` int(10) UNSIGNED NOT NULL DEFAULT 1540994454,
  `ip6` varchar(42) NOT NULL DEFAULT '2001:9b1:8528:42::150',
  `apacheExtra` mediumtext NOT NULL DEFAULT '',
  `forward` tinyint(3) UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Skicka vidare webbtrafik',
  `fastcgi` tinyint(3) UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Ska php-fpm användas',
  `webusage` bigint(20) UNSIGNED NOT NULL DEFAULT 0,
  `ip` varchar(42) NOT NULL DEFAULT '91.217.181.150'
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci COMMENT='Webbplatser åt våra kunder';

-- --------------------------------------------------------

--
-- Table structure for table `DomainAlias`
--

CREATE TABLE `DomainAlias` (
                             `id` int(10) UNSIGNED NOT NULL,
  `domainAlias` varchar(191) NOT NULL DEFAULT '',
  `domainFK` int(10) UNSIGNED NOT NULL DEFAULT 0
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `domainDebt`
--

CREATE TABLE `domainDebt` (
                            `domainid` int(10) UNSIGNED NOT NULL COMMENT 'Kopplad till tabellen domain',
  `invoiceitemid` int(11) UNSIGNED NOT NULL COMMENT 'Kopplad till tabellen invoiceitem',
  `id` int(10) UNSIGNED NOT NULL
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci COMMENT='För att märka domäner som obetalda';

-- --------------------------------------------------------

--
-- Table structure for table `domainLog`
--

CREATE TABLE `domainLog` (
                           `logid` int(11) NOT NULL,
  `domainname` varchar(191) NOT NULL DEFAULT '',
  `customerid` int(11) UNSIGNED NOT NULL DEFAULT 0,
  `logtime` datetime NOT NULL,
  `logtext` varchar(191) NOT NULL DEFAULT '',
  `ip` varchar(42) NOT NULL DEFAULT ''
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci COMMENT='Händelselogg för domäner';

-- --------------------------------------------------------

--
-- Table structure for table `domainsale`
--

CREATE TABLE `domainsale` (
                            `saleid` int(10) UNSIGNED NOT NULL,
  `domainid` int(11) UNSIGNED NOT NULL,
  `customerid` int(10) UNSIGNED NOT NULL,
  `price` float NOT NULL DEFAULT 0
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `eppSlotNU`
--

CREATE TABLE `eppSlotNU` (
                           `counter` int(10) UNSIGNED NOT NULL,
  `connectTime` datetime NOT NULL,
  `remote_host` varchar(16) DEFAULT ''
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `eppSlotSE`
--

CREATE TABLE `eppSlotSE` (
                           `counter` int(10) UNSIGNED NOT NULL,
  `connectTime` datetime NOT NULL,
  `remote_host` varchar(16) DEFAULT ''
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `eu_vat`
--

CREATE TABLE `eu_vat` (
                        `iso` char(2) NOT NULL,
  `updated` date NOT NULL,
  `fraction` decimal(3,0) UNSIGNED NOT NULL
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci COMMENT='Momssatser för EU-länder';

-- --------------------------------------------------------

--
-- Table structure for table `forsale`
--

CREATE TABLE `forsale` (
                         `id` int(10) UNSIGNED NOT NULL,
  `customerid` int(10) UNSIGNED NOT NULL,
  `domainid` int(10) UNSIGNED NOT NULL,
  `price` int(10) UNSIGNED NOT NULL,
  `buynow` tinyint(1) NOT NULL DEFAULT 0,
  `sold` datetime DEFAULT NULL,
  `published` datetime DEFAULT NULL
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `ForwardDomain`
--

CREATE TABLE `ForwardDomain` (
                               `forwardid` int(10) UNSIGNED NOT NULL,
  `target` varchar(191) NOT NULL,
  `domainFK` int(11) UNSIGNED NOT NULL DEFAULT 0
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `iitt`
--

CREATE TABLE `iitt` (
                      `invoiceitemid` int(11) UNSIGNED NOT NULL,
  `invoiceid` int(11) UNSIGNED NOT NULL DEFAULT 0,
  `productid` int(11) UNSIGNED NOT NULL DEFAULT 0,
  `invoiceitemtext` varchar(191) NOT NULL DEFAULT '',
  `price` float NOT NULL DEFAULT 0,
  `vat` float NOT NULL DEFAULT 0.25,
  `customerid` int(11) UNSIGNED NOT NULL DEFAULT 0,
  `number` int(11) UNSIGNED NOT NULL DEFAULT 1,
  `include` int(11) UNSIGNED NOT NULL DEFAULT 1
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `invoice`
--

CREATE TABLE `invoice` (
                         `invoiceid` int(11) UNSIGNED NOT NULL,
  `customerid` int(11) UNSIGNED NOT NULL DEFAULT 0,
  `state` enum('obehandlad','ofakturerad','fakturerad','bokford','raderad','krediterad','pamind','inkasso','kronofogden') NOT NULL DEFAULT 'obehandlad',
  `updated` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `invoicedate` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `vat` float NOT NULL DEFAULT 0.25,
  `totalcost` float NOT NULL DEFAULT 0,
  `debt` float NOT NULL DEFAULT 0,
  `currency` enum('sek','eur') NOT NULL DEFAULT 'sek',
  `bookingdate` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `uuid` varchar(191) NOT NULL DEFAULT '',
  `paydate` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `fakturanummer` bigint(20) UNSIGNED NOT NULL DEFAULT 0,
  `kreditfakturaavser` int(11) UNSIGNED NOT NULL DEFAULT 0,
  `dontremind` tinyint(3) UNSIGNED NOT NULL DEFAULT 0,
  `rev` tinyint(3) UNSIGNED NOT NULL DEFAULT 0
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `invoiceEPay`
--

CREATE TABLE `invoiceEPay` (
                             `invoiceid` int(11) NOT NULL COMMENT 'Kopplad till invoice',
  `txnid` int(11) NOT NULL COMMENT 'Transaktionsid hos ePay',
  `amount` int(11) NOT NULL COMMENT 'Summan från callbacken',
  `cardno` varchar(63) NOT NULL COMMENT 'Maskerat kortnummer',
  `paymenttype` int(11) NOT NULL COMMENT 'Betalningssätt',
  `received` datetime NOT NULL COMMENT 'Anropstid',
  `txnfee` int(11) NOT NULL COMMENT 'Kortavgift',
  `currency` int(11) NOT NULL COMMENT 'valutakod'
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `invoiceitem`
--

CREATE TABLE `invoiceitem` (
                             `invoiceitemid` int(11) UNSIGNED NOT NULL,
  `invoiceid` int(11) UNSIGNED NOT NULL DEFAULT 0,
  `productid` int(11) UNSIGNED NOT NULL DEFAULT 0,
  `invoiceitemtext` varchar(191) NOT NULL DEFAULT '',
  `price` float NOT NULL DEFAULT 0,
  `vat` float NOT NULL DEFAULT 0.25,
  `customerid` int(11) UNSIGNED NOT NULL DEFAULT 0,
  `number` int(11) UNSIGNED NOT NULL DEFAULT 1,
  `include` int(11) UNSIGNED NOT NULL DEFAULT 1,
  `test` tinyint(3) UNSIGNED NOT NULL DEFAULT 0,
  `articlenumber` int(10) UNSIGNED NOT NULL DEFAULT 0
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `invoicepack`
--

CREATE TABLE `invoicepack` (
                             `id` int(10) UNSIGNED NOT NULL,
  `startnummer` bigint(20) UNSIGNED NOT NULL,
  `slutnummer` bigint(20) UNSIGNED NOT NULL,
  `created` date NOT NULL DEFAULT current_timestamp()
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `invoicepayment`
--

CREATE TABLE `invoicepayment` (
                                `paymentid` int(10) UNSIGNED NOT NULL,
  `invoiceid` int(10) UNSIGNED NOT NULL,
  `customerid` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `paydate` date NOT NULL,
  `amount` float NOT NULL DEFAULT 0,
  `updater` varchar(31) NOT NULL,
  `updated` datetime NOT NULL DEFAULT current_timestamp()
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `invoicereminder`
--

CREATE TABLE `invoicereminder` (
                                 `reminderid` int(11) UNSIGNED NOT NULL,
  `customerid` int(11) UNSIGNED NOT NULL DEFAULT 0,
  `invoiceid` int(11) UNSIGNED NOT NULL DEFAULT 0,
  `reminderdate` datetime NOT NULL DEFAULT current_timestamp()
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `loginfailures`
--

CREATE TABLE `loginfailures` (
                               `loginfailureid` int(10) UNSIGNED NOT NULL,
  `ip` varchar(42) CHARACTER SET ascii COLLATE ascii_general_ci NOT NULL,
  `failuretime` datetime NOT NULL DEFAULT current_timestamp(),
  `username` varchar(191) NOT NULL DEFAULT ''
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `maildomain`
--

CREATE TABLE `maildomain` (
                            `domainname` varchar(191) NOT NULL,
  `customerid` int(11) NOT NULL DEFAULT 0,
  `mailusage` bigint(20) UNSIGNED NOT NULL DEFAULT 0,
  `updated` datetime NOT NULL DEFAULT current_timestamp()
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `maildomainalias`
--

CREATE TABLE `maildomainalias` (
                                 `aliasname` varchar(191) NOT NULL,
  `domainname` varchar(191) NOT NULL
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `nameserver`
--

CREATE TABLE `nameserver` (
                            `nsid` int(10) UNSIGNED NOT NULL,
  `nameserver` varchar(128) NOT NULL DEFAULT '',
  `glue` varchar(128) DEFAULT NULL
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `pamlog`
--

CREATE TABLE `pamlog` (
                        `logid` int(11) NOT NULL,
  `loguser` char(63) NOT NULL DEFAULT '',
  `logtime` datetime NOT NULL,
  `logpid` int(11) NOT NULL DEFAULT 0,
  `loghost` char(20) NOT NULL DEFAULT '',
  `logmessage` char(63) NOT NULL DEFAULT '',
  `logrhost` char(63) NOT NULL DEFAULT ''
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `passwords`
--

CREATE TABLE `passwords` (
                           `id` int(11) UNSIGNED NOT NULL,
  `passwordmysqlcrypt` varchar(191) DEFAULT NULL,
  `passwordsha512crypt` varchar(191) DEFAULT NULL,
  `passwordpbkdf2crypt` varchar(191) DEFAULT NULL,
  `passwordbcrypt` varchar(191) DEFAULT NULL,
  `passwordargon2crypt` varchar(191) DEFAULT NULL,
  `updated` datetime NOT NULL DEFAULT current_timestamp(),
  `userid` int(11) UNSIGNED NOT NULL
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `payments`
--

CREATE TABLE `payments` (
                          `paymentid` int(10) UNSIGNED NOT NULL,
  `invoiceid` int(10) UNSIGNED NOT NULL,
  `paydate` date NOT NULL,
  `amount` decimal(2,0) NOT NULL,
  `updater` varchar(31) NOT NULL,
  `updated` datetime NOT NULL DEFAULT current_timestamp()
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `pendingAuthcodes`
--

CREATE TABLE `pendingAuthcodes` (
                                  `pAid` int(10) UNSIGNED NOT NULL,
  `domainid` int(10) UNSIGNED NOT NULL COMMENT 'Kopplat till domain'
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci COMMENT='Domäner som ska få en authcode eftersom de är betalade';

-- --------------------------------------------------------

--
-- Table structure for table `product`
--

CREATE TABLE `product` (
                         `productid` int(11) NOT NULL,
  `productname` varchar(191) NOT NULL DEFAULT '',
  `price_sek` float NOT NULL DEFAULT 0,
  `price_nok` float NOT NULL DEFAULT 0,
  `price_eur` float NOT NULL DEFAULT 0,
  `price_gbp` float NOT NULL DEFAULT 0,
  `price_usd` float NOT NULL DEFAULT 0,
  `price_dkk` float NOT NULL DEFAULT 0,
  `updated` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `updater` varchar(191) NOT NULL DEFAULT '',
  `created` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `creator` varchar(191) NOT NULL DEFAULT '',
  `active` tinyint(3) UNSIGNED NOT NULL DEFAULT 1,
  `producttype` enum('subscription','other','cleansnap') NOT NULL DEFAULT 'subscription',
  `description` mediumtext NOT NULL
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `registrantid`
--

CREATE TABLE `registrantid` (
                              `registrantid` varchar(191) NOT NULL DEFAULT '',
  `orgno` varchar(191) NOT NULL DEFAULT '',
  `tld` varchar(191) NOT NULL DEFAULT 'SE',
  `customerid` int(11) NOT NULL DEFAULT 0,
  `lasttouch` datetime NOT NULL DEFAULT current_timestamp(),
  `verified` datetime DEFAULT NULL,
  `contactid` int(10) UNSIGNED DEFAULT NULL
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `registry`
--

CREATE TABLE `registry` (
                          `registryid` tinyint(3) UNSIGNED NOT NULL,
  `registryname` varchar(191) NOT NULL DEFAULT ''
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `reminder`
--

CREATE TABLE `reminder` (
                          `reminderid` int(11) UNSIGNED NOT NULL,
  `customerid` int(11) UNSIGNED NOT NULL DEFAULT 0,
  `invoiceid` int(11) UNSIGNED NOT NULL DEFAULT 0,
  `reminderdate` datetime NOT NULL DEFAULT '0000-00-00 00:00:00'
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `server`
--

CREATE TABLE `server` (
                        `id` int(10) UNSIGNED NOT NULL,
  `servername` varchar(32) NOT NULL,
  `backendip` bigint(20) UNSIGNED NOT NULL
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `server_tmp`
--

CREATE TABLE `server_tmp` (
                            `id` int(10) UNSIGNED NOT NULL,
  `servername` varchar(32) NOT NULL,
  `backendip` bigint(20) UNSIGNED NOT NULL
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `Service`
--

CREATE TABLE `Service` (
                         `serviceId` int(10) UNSIGNED NOT NULL,
  `serviceTypeFK` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `domainName` varchar(191) NOT NULL DEFAULT '',
  `serviceName` varchar(50) NOT NULL DEFAULT '',
  `serviceAlias` varchar(50) NOT NULL DEFAULT '',
  `accountFK` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `datestamp` date NOT NULL DEFAULT '0000-00-00',
  `statusTypeFK` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `cost` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `memo` varchar(191) DEFAULT NULL
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `ServiceType`
--

CREATE TABLE `ServiceType` (
                             `serviceTypeId` int(10) UNSIGNED NOT NULL,
  `serviceTypeName` varchar(191) NOT NULL DEFAULT '',
  `datestamp` date NOT NULL DEFAULT '0000-00-00',
  `description` varchar(191) DEFAULT NULL
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `snapallsessions`
--

CREATE TABLE `snapallsessions` (
                                 `allsessionid` int(11) NOT NULL,
  `value` varchar(191) NOT NULL DEFAULT '',
  `userlogin` varchar(191) NOT NULL DEFAULT '',
  `logintime` timestamp NOT NULL DEFAULT current_timestamp(),
  `remote_host` varchar(42) NOT NULL DEFAULT ''
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `snapback`
--

CREATE TABLE `snapback` (
                          `id` int(11) NOT NULL,
  `message` mediumtext NOT NULL,
  `sendtime` datetime NOT NULL,
  `domainname` varchar(191) NOT NULL DEFAULT ''
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `snapprices`
--

CREATE TABLE `snapprices` (
                            `price_sek` float DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `snapsession`
--

CREATE TABLE `snapsession` (
                             `sessionid` int(11) NOT NULL,
  `value` varchar(191) NOT NULL DEFAULT '',
  `userlogin` varchar(191) NOT NULL DEFAULT '',
  `lasttime` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `remote_host` varchar(42) NOT NULL DEFAULT '',
  `impersonateuserlogin` varchar(191) NOT NULL DEFAULT '',
  `impersonatecustomerid` int(10) UNSIGNED NOT NULL DEFAULT 0,
  `impersonatelang` varchar(191) NOT NULL DEFAULT 'sv_SE'
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `snapusers`
--

CREATE TABLE `snapusers` (
                           `id` int(10) UNSIGNED NOT NULL,
  `userlogin` varchar(191) NOT NULL DEFAULT '',
  `orgno` varchar(191) NOT NULL DEFAULT '',
  `customerid` int(11) UNSIGNED NOT NULL DEFAULT 0,
  `org` varchar(191) NOT NULL DEFAULT '',
  `name` varchar(191) NOT NULL DEFAULT '',
  `street` varchar(191) NOT NULL DEFAULT '',
  `pc` varchar(191) NOT NULL DEFAULT '',
  `city` varchar(191) NOT NULL DEFAULT '',
  `st` varchar(191) NOT NULL DEFAULT '' COMMENT 'Stat eller provins',
  `cc` varchar(191) NOT NULL DEFAULT '',
  `email` varchar(191) NOT NULL DEFAULT '',
  `phone` varchar(191) NOT NULL DEFAULT '',
  `confirmed` tinyint(3) UNSIGNED NOT NULL DEFAULT 0,
  `blocked` tinyint(3) UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Blockeringsskal',
  `fax` varchar(191) NOT NULL DEFAULT '',
  `lang` varchar(191) NOT NULL DEFAULT 'sv_SE' COMMENT 'Sprakval for texter',
  `vatno` varchar(191) NOT NULL DEFAULT '',
  `registrantid` varchar(191) NOT NULL DEFAULT '' COMMENT 'Kontakt-Id for .se',
  `registrantidnu` varchar(191) NOT NULL DEFAULT '' COMMENT 'Kontakt-Id for .nu',
  `created` datetime DEFAULT NULL,
  `updated` datetime DEFAULT NULL,
  `uuid` varchar(191) NOT NULL DEFAULT '',
  `pendingemail` varchar(191) NOT NULL DEFAULT '',
  `lastip` varchar(42) NOT NULL DEFAULT ''
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `StatusType`
--

CREATE TABLE `StatusType` (
                            `statusTypeId` int(10) UNSIGNED NOT NULL,
  `statusTypeName` varchar(50) NOT NULL DEFAULT '',
  `memo` varchar(191) DEFAULT NULL
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `subscription`
--

CREATE TABLE `subscription` (
                              `productid` int(11) UNSIGNED NOT NULL DEFAULT 0,
  `customerid` int(11) UNSIGNED NOT NULL DEFAULT 0,
  `lastinvoice` datetime NOT NULL DEFAULT '0000-00-00 00:00:00'
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `user`
--

CREATE TABLE `user` (
                      `pw_name` char(32) NOT NULL DEFAULT '',
  `pw_domain` varchar(191) NOT NULL DEFAULT ''
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `userGroup`
--

CREATE TABLE `userGroup` (
                           `id` int(11) UNSIGNED NOT NULL,
  `user_id` int(11) UNSIGNED NOT NULL,
  `group_id` int(11) UNSIGNED NOT NULL
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `valutakurs`
--

CREATE TABLE `valutakurs` (
                            `datum` date NOT NULL,
                            `valuta` enum('sek','nok','usd','eur','dkk','gbp') NOT NULL,
  `rate` decimal(6,5) NOT NULL
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_swedish_ci COMMENT='Valutakurser';

--
-- Indexes for dumped tables
--

--
-- Indexes for table `Account`
--
ALTER TABLE `Account`
  ADD PRIMARY KEY (`accountPK`);

--
-- Indexes for table `accountbook`
--
ALTER TABLE `accountbook`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `accountchart`
--
ALTER TABLE `accountchart`
  ADD PRIMARY KEY (`accountnumber`);

--
-- Indexes for table `AllSessions`
--
ALTER TABLE `AllSessions`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `certs`
--
ALTER TABLE `certs`
  ADD PRIMARY KEY (`certid`),
  ADD KEY `origintype` (`origintype`);

--
-- Indexes for table `contact`
--
ALTER TABLE `contact`
  ADD PRIMARY KEY (`contactid`);

--
-- Indexes for table `contactTypes`
--
ALTER TABLE `contactTypes`
  ADD PRIMARY KEY (`typeId`);

--
-- Indexes for table `countryinfo`
--
ALTER TABLE `countryinfo`
  ADD PRIMARY KEY (`iso`),
  ADD UNIQUE KEY `iso3` (`iso3`),
  ADD UNIQUE KEY `ISONumeric` (`ISONumeric`);

--
-- Indexes for table `customer`
--
ALTER TABLE `customer`
  ADD PRIMARY KEY (`customerid`),
  ADD KEY `company_firstname_lastname` (`company`,`firstname`,`lastname`);

--
-- Indexes for table `databases`
--
ALTER TABLE `databases`
  ADD PRIMARY KEY (`databaseid`),
  ADD UNIQUE KEY `databasename` (`databasename`);

--
-- Indexes for table `defaultDNS`
--
ALTER TABLE `defaultDNS`
  ADD UNIQUE KEY `unik` (`userlogin`,`dns`);

--
-- Indexes for table `dnsDomain`
--
ALTER TABLE `dnsDomain`
  ADD PRIMARY KEY (`domainname`),
  ADD KEY `customerid` (`customerid`);

--
-- Indexes for table `dnssec`
--
ALTER TABLE `dnssec`
  ADD PRIMARY KEY (`id`),
  ADD KEY `customerid` (`customerid`);

--
-- Indexes for table `domain`
--
ALTER TABLE `domain`
  ADD PRIMARY KEY (`domainid`),
  ADD UNIQUE KEY `domainname_2` (`domainname`),
  ADD KEY `registryid` (`registryid`),
  ADD KEY `domainname` (`domainname`);

--
-- Indexes for table `Domain`
--
ALTER TABLE `Domain`
  ADD PRIMARY KEY (`domainPK`),
  ADD KEY `server` (`server`);

--
-- Indexes for table `DomainAlias`
--
ALTER TABLE `DomainAlias`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `domainDebt`
--
ALTER TABLE `domainDebt`
  ADD PRIMARY KEY (`id`),
  ADD KEY `domainid` (`domainid`),
  ADD KEY `invoiceitemid` (`invoiceitemid`);

--
-- Indexes for table `domainLog`
--
ALTER TABLE `domainLog`
  ADD PRIMARY KEY (`logid`);

--
-- Indexes for table `domainsale`
--
ALTER TABLE `domainsale`
  ADD PRIMARY KEY (`saleid`),
  ADD KEY `customerid` (`customerid`);

--
-- Indexes for table `eppSlotNU`
--
ALTER TABLE `eppSlotNU`
  ADD PRIMARY KEY (`counter`);

--
-- Indexes for table `eppSlotSE`
--
ALTER TABLE `eppSlotSE`
  ADD PRIMARY KEY (`counter`);

--
-- Indexes for table `eu_vat`
--
ALTER TABLE `eu_vat`
  ADD UNIQUE KEY `iso` (`iso`,`updated`);

--
-- Indexes for table `forsale`
--
ALTER TABLE `forsale`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `ForwardDomain`
--
ALTER TABLE `ForwardDomain`
  ADD PRIMARY KEY (`forwardid`);

--
-- Indexes for table `iitt`
--
ALTER TABLE `iitt`
  ADD PRIMARY KEY (`invoiceitemid`),
  ADD KEY `invoiceid` (`invoiceid`),
  ADD KEY `customerid` (`customerid`);

--
-- Indexes for table `invoice`
--
ALTER TABLE `invoice`
  ADD PRIMARY KEY (`invoiceid`),
  ADD KEY `customerid` (`customerid`),
  ADD KEY `invoicedate` (`invoicedate`);

--
-- Indexes for table `invoiceEPay`
--
ALTER TABLE `invoiceEPay`
  ADD PRIMARY KEY (`invoiceid`,`txnid`);

--
-- Indexes for table `invoiceitem`
--
ALTER TABLE `invoiceitem`
  ADD PRIMARY KEY (`invoiceitemid`),
  ADD KEY `invoiceid` (`invoiceid`),
  ADD KEY `customerid` (`customerid`),
  ADD KEY `test` (`test`);

--
-- Indexes for table `invoicepack`
--
ALTER TABLE `invoicepack`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `invoicepayment`
--
ALTER TABLE `invoicepayment`
  ADD PRIMARY KEY (`paymentid`);

--
-- Indexes for table `invoicereminder`
--
ALTER TABLE `invoicereminder`
  ADD PRIMARY KEY (`reminderid`);

--
-- Indexes for table `loginfailures`
--
ALTER TABLE `loginfailures`
  ADD PRIMARY KEY (`loginfailureid`);

--
-- Indexes for table `maildomain`
--
ALTER TABLE `maildomain`
  ADD PRIMARY KEY (`domainname`);

--
-- Indexes for table `maildomainalias`
--
ALTER TABLE `maildomainalias`
  ADD PRIMARY KEY (`aliasname`);

--
-- Indexes for table `nameserver`
--
ALTER TABLE `nameserver`
  ADD PRIMARY KEY (`nsid`),
  ADD UNIQUE KEY `nameserver` (`nameserver`);

--
-- Indexes for table `pamlog`
--
ALTER TABLE `pamlog`
  ADD PRIMARY KEY (`logid`);

--
-- Indexes for table `passwords`
--
ALTER TABLE `passwords`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `payments`
--
ALTER TABLE `payments`
  ADD PRIMARY KEY (`paymentid`);

--
-- Indexes for table `pendingAuthcodes`
--
ALTER TABLE `pendingAuthcodes`
  ADD PRIMARY KEY (`pAid`);

--
-- Indexes for table `product`
--
ALTER TABLE `product`
  ADD PRIMARY KEY (`productid`);

--
-- Indexes for table `registrantid`
--
ALTER TABLE `registrantid`
  ADD PRIMARY KEY (`registrantid`,`tld`);

--
-- Indexes for table `registry`
--
ALTER TABLE `registry`
  ADD PRIMARY KEY (`registryid`),
  ADD UNIQUE KEY `registryname` (`registryname`);

--
-- Indexes for table `reminder`
--
ALTER TABLE `reminder`
  ADD PRIMARY KEY (`reminderid`);

--
-- Indexes for table `server`
--
ALTER TABLE `server`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `servername` (`servername`);

--
-- Indexes for table `server_tmp`
--
ALTER TABLE `server_tmp`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `servername` (`servername`);

--
-- Indexes for table `Service`
--
ALTER TABLE `Service`
  ADD PRIMARY KEY (`serviceTypeFK`,`domainName`,`serviceName`),
  ADD KEY `serviceId` (`serviceId`);

--
-- Indexes for table `ServiceType`
--
ALTER TABLE `ServiceType`
  ADD PRIMARY KEY (`serviceTypeName`),
  ADD KEY `serviceTypeId` (`serviceTypeId`);

--
-- Indexes for table `snapallsessions`
--
ALTER TABLE `snapallsessions`
  ADD PRIMARY KEY (`allsessionid`);

--
-- Indexes for table `snapback`
--
ALTER TABLE `snapback`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `snapsession`
--
ALTER TABLE `snapsession`
  ADD PRIMARY KEY (`sessionid`);

--
-- Indexes for table `snapusers`
--
ALTER TABLE `snapusers`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `userlogin` (`userlogin`) USING BTREE;

--
-- Indexes for table `StatusType`
--
ALTER TABLE `StatusType`
  ADD PRIMARY KEY (`statusTypeId`);

--
-- Indexes for table `subscription`
--
ALTER TABLE `subscription`
  ADD PRIMARY KEY (`customerid`,`productid`);

--
-- Indexes for table `user`
--
ALTER TABLE `user`
  ADD PRIMARY KEY (`pw_name`,`pw_domain`);

--
-- Indexes for table `userGroup`
--
ALTER TABLE `userGroup`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `valutakurs`
--
ALTER TABLE `valutakurs`
  ADD UNIQUE KEY `ptyh` (`datum`,`valuta`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `Account`
--
ALTER TABLE `Account`
  MODIFY `accountPK` int(10) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `accountbook`
--
ALTER TABLE `accountbook`
  MODIFY `id` int(11) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=61440;

--
-- AUTO_INCREMENT for table `AllSessions`
--
ALTER TABLE `AllSessions`
  MODIFY `id` int(11) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `certs`
--
ALTER TABLE `certs`
  MODIFY `certid` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=267;

--
-- AUTO_INCREMENT for table `contact`
--
ALTER TABLE `contact`
  MODIFY `contactid` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2131;

--
-- AUTO_INCREMENT for table `contactTypes`
--
ALTER TABLE `contactTypes`
  MODIFY `typeId` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT for table `customer`
--
ALTER TABLE `customer`
  MODIFY `customerid` int(11) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3702;

--
-- AUTO_INCREMENT for table `databases`
--
ALTER TABLE `databases`
  MODIFY `databaseid` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=335;

--
-- AUTO_INCREMENT for table `dnssec`
--
ALTER TABLE `dnssec`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `domain`
--
ALTER TABLE `domain`
  MODIFY `domainid` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=55682;

--
-- AUTO_INCREMENT for table `Domain`
--
ALTER TABLE `Domain`
  MODIFY `domainPK` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=10774;

--
-- AUTO_INCREMENT for table `DomainAlias`
--
ALTER TABLE `DomainAlias`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=345;

--
-- AUTO_INCREMENT for table `domainDebt`
--
ALTER TABLE `domainDebt`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=24035;

--
-- AUTO_INCREMENT for table `domainLog`
--
ALTER TABLE `domainLog`
  MODIFY `logid` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=120489;

--
-- AUTO_INCREMENT for table `domainsale`
--
ALTER TABLE `domainsale`
  MODIFY `saleid` int(10) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `eppSlotNU`
--
ALTER TABLE `eppSlotNU`
  MODIFY `counter` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=70072;

--
-- AUTO_INCREMENT for table `eppSlotSE`
--
ALTER TABLE `eppSlotSE`
  MODIFY `counter` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=124581;

--
-- AUTO_INCREMENT for table `forsale`
--
ALTER TABLE `forsale`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `ForwardDomain`
--
ALTER TABLE `ForwardDomain`
  MODIFY `forwardid` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=15;

--
-- AUTO_INCREMENT for table `iitt`
--
ALTER TABLE `iitt`
  MODIFY `invoiceitemid` int(11) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=85807;

--
-- AUTO_INCREMENT for table `invoice`
--
ALTER TABLE `invoice`
  MODIFY `invoiceid` int(11) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=27098;

--
-- AUTO_INCREMENT for table `invoiceitem`
--
ALTER TABLE `invoiceitem`
  MODIFY `invoiceitemid` int(11) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=125871;

--
-- AUTO_INCREMENT for table `invoicepack`
--
ALTER TABLE `invoicepack`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=94;

--
-- AUTO_INCREMENT for table `invoicepayment`
--
ALTER TABLE `invoicepayment`
  MODIFY `paymentid` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=18720;

--
-- AUTO_INCREMENT for table `invoicereminder`
--
ALTER TABLE `invoicereminder`
  MODIFY `reminderid` int(11) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4975;

--
-- AUTO_INCREMENT for table `loginfailures`
--
ALTER TABLE `loginfailures`
  MODIFY `loginfailureid` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `nameserver`
--
ALTER TABLE `nameserver`
  MODIFY `nsid` int(10) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `pamlog`
--
ALTER TABLE `pamlog`
  MODIFY `logid` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1823;

--
-- AUTO_INCREMENT for table `passwords`
--
ALTER TABLE `passwords`
  MODIFY `id` int(11) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2749;

--
-- AUTO_INCREMENT for table `payments`
--
ALTER TABLE `payments`
  MODIFY `paymentid` int(10) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `pendingAuthcodes`
--
ALTER TABLE `pendingAuthcodes`
  MODIFY `pAid` int(10) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `product`
--
ALTER TABLE `product`
  MODIFY `productid` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=131;

--
-- AUTO_INCREMENT for table `registry`
--
ALTER TABLE `registry`
  MODIFY `registryid` tinyint(3) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=21;

--
-- AUTO_INCREMENT for table `reminder`
--
ALTER TABLE `reminder`
  MODIFY `reminderid` int(11) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4749;

--
-- AUTO_INCREMENT for table `server`
--
ALTER TABLE `server`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `server_tmp`
--
ALTER TABLE `server_tmp`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `Service`
--
ALTER TABLE `Service`
  MODIFY `serviceId` int(10) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `ServiceType`
--
ALTER TABLE `ServiceType`
  MODIFY `serviceTypeId` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT for table `snapallsessions`
--
ALTER TABLE `snapallsessions`
  MODIFY `allsessionid` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=21337;

--
-- AUTO_INCREMENT for table `snapback`
--
ALTER TABLE `snapback`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=24;

--
-- AUTO_INCREMENT for table `snapsession`
--
ALTER TABLE `snapsession`
  MODIFY `sessionid` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=204019;

--
-- AUTO_INCREMENT for table `snapusers`
--
ALTER TABLE `snapusers`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2103;

--
-- AUTO_INCREMENT for table `StatusType`
--
ALTER TABLE `StatusType`
  MODIFY `statusTypeId` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `userGroup`
--
ALTER TABLE `userGroup`
  MODIFY `id` int(11) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=557;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
