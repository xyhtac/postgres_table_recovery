#!/usr/bin/perl -w
use DBI;

$dbname = "dbname";					# Database name
$username = "dbuser";					# DB username
$password = "secretpassword";				# DB password
$dbhost = "localhost";					# DB hostname
$dbport = "5432";					# DB Port
$dboptions = "-e";					# DBI options
$dbtty = "ansi";					# DB Charset

$table = "tablename";					# Working table
$write = 0; 						# Passive mode switch
$verbose = 0;						# Output additional diagnostic data


$qu = 0;
$timestamp_start = time();
$dbh = DBI->connect("dbi:Pg:dbname=$dbname;host=$dbhost;port=$dbport;options=$dboptions;tty=$dbtty","$username","$password",
            {PrintError => 0});

&check_range(0, &get_row_count($table), $table);
@table_fields = &get_field_names($table);

$timespan = time() - $timestamp_start;
$count = keys %offsets;

print "\nSCAN COMPLETE IN $timespan S\nfound $count corrupted rows. $qu database queries performed. \n\n";

foreach $ofst (keys %offsets) {
	print "$offsets{$ofst} \n" if $verbose;
	foreach $field (@table_fields) {
		if ( &query_dbi($table,1,$ofst,$field) ) {
			$ident = &get_row_id($table, $ofst);
			print "id: $ident; field: $field at offset $ofst corruped.\n";
			if ($write) {
				$result = &update_dbi($table,$field,$ident);
				print $result;
			} else {
				print "Diagnostic mode, 0 bytes written.\n";
			}
		} else {
			
		}
	}
}

print "\nSEQUENCE COMPLETE\n\n";

sub check_range {
	local ($range_start, $range_end, $table) = @_ if @_;
	
	print "Checking range: $range_start -- $range_end\n";

	if ($range_start >= $range_end) {
		local $errval = &query_dbi($table,'1',$range_start);
		if ( $errval ) {
			$offsets{$range_start} = "$errval; offset: $range_start";
			print "Found error at offset $range_start\n" if $verbose;
		} else {

		}
	} else {
		$pre_median = ($range_end - $range_start) / 2 ;
		if ( ($range_end-$range_start) / 2 != int( ($range_end-$range_start) / 2 ) ) {
			$midrange = int($pre_median);
			$tail = 1;
		} else {
			$midrange = $pre_median;
			$tail = 0;
		}

		local $lower_median = $midrange;
		local $lower_start = $range_start;
		local $lower_end = $range_start + $lower_median;
		$lower_median = 1 if $lower_median < 1;
		
		local $upper_median = $midrange + $tail;
		local $upper_start = $range_start + $upper_median;
		local $upper_end = $range_end;
		$upper_median = 1 if $upper_median < 1;
		
		print "CHECKING LOWER: $lower_start ... $lower_end  LIMIT:$lower_median \n" if $verbose;
		if ( &query_dbi($table,$lower_median+1,$lower_start) ) {
			print "               ^^^^^^ triggered here \n\n" if $verbose;
			&check_range($lower_start, $lower_end, $table);
		}
		
		print "CHECKING UPPER: $upper_start ... $upper_end LIMIT:$upper_median \n" if $verbose;
		if ( &query_dbi($table,$upper_median+1,$upper_start) ) {
			print "                ^^^^^^ triggered here \n\n" if $verbose;
			&check_range($upper_start, $upper_end, $table);
		}
	}
}

sub query_dbi {
	local ($table,$limit,$offset,$field) = @_ if @_;
	$qu++;
	local $field = "*" unless $field;
	local $query = "SELECT $field FROM $table ORDER BY ID LIMIT $limit OFFSET $offset";
	local $sth = $dbh->prepare($query);
	local $rv = $sth->execute();
	if (!defined $rv) {
		return $dbh->errstr;
	} else	{ 
		return "" 
	}
}



sub get_row_count {
	local ($table) = @_ if @_;
	$qu++;
	local $query = "SELECT COUNT(*) FROM $table";
	$sth = $dbh->prepare($query);
	$rv = $sth->execute();
	@row = $sth->fetchrow_array();
	return $row[0];
}

sub get_field_names {
	local ($table) = @_ if @_;
	$qu++;
	local $query = "SELECT column_name from information_schema.columns where table_name = '$table'";
	$sth = $dbh->prepare($query);
	$rv = $sth->execute();
	while (@rows = $sth->fetchrow_array()) {;
		push (@out, join('',@rows) );
	}
	return @out;
}

sub get_row_id {
	local ($table,$offset) = @_ if @_;
	$qu++;
	local @ids;
	local $query = "SELECT id FROM $table ORDER BY ID LIMIT 1 OFFSET $offset";
	$sth = $dbh->prepare($query);
	$rv = $sth->execute();
	while (@rws = $sth->fetchrow_array()) {;
		push (@ids, join('',@rws) );
	}
	return $ids[0];
}

sub update_dbi {
	local ($table,$field,$ident) = @_ if @_;
	$qu++;
	local $query = "UPDATE $table SET $field = '' WHERE id = $ident";
	$dbh->begin_work();
	$rv = $dbh->do($query);
	$dbh->commit();
	if (!defined $rv) {
		return "Update failed: " . $dbh->errstr . "\n";
	} else {
		return "Update Ok\n";
	}
}


$sth->finish();
$dbh->disconnect();

