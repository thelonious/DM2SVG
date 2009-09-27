#!/usr/bin/perl -w
#####
#
#   DigiSVG.pl
#   written by Kevin Lindsey
#   copyright 2005
#
#####

if (@ARGV) {
    process_file(shift);
} else {
    print STDERR "usage: $0 <dhw-file>";
}


#####
#
#   process_file
#
#####
sub process_file {
    my $file = shift;
    
    if (open INPUT, $file) {
        binmode(INPUT);

        my $height = emit_header();
        
        while (not eof(INPUT)) {
            my $tag = read_byte();
            
            if ($tag >= 128) {
                if ($tag == 0x90) {
                    emit_comment("End Layer " . read_byte());
                } elsif ($tag == 0x88) {
                    emit_comment("Timestamp = " . read_timestamp() . "ms");
                } else {
                    my @coords;

                    # pen down
                    while (not eof(INPUT)) {
                        push @coords, read_point($height);
                        last if peek_byte() >= 128;
                    }

                    # pen up
                    read_byte();
                    push @coords, read_point($height);
                    emit_polyline(\@coords);
                }
            } else {
                print STDERR "Unsupported tag: $tag\n";
            }
        }

        emit_footer();

        close INPUT;
    } else {
        print STDERR "Unable to open $file: $!";
    }
}

#####
#
#   peek_byte
#
#####
sub peek_byte {
    my $cur_pos = tell(INPUT);
    my $result = read_byte();

    seek(INPUT, $cur_pos, 0);
    
    return $result;
}

#####
#
#   read_byte
#
#####
sub read_byte {
    my $data;

    read INPUT, $data, 1;
    
    return unpack("C", $data);
}

#####
#
#   read_point
#
#####
sub read_point {
    my $ymax = shift;
    my $data;

    read INPUT, $data, 4;

    my ($x1, $x2, $y1, $y2) =
        unpack("CCCC", $data);
    my $x = $x1 | $x2 << 7;
    my $y = $y1 | $y2 << 7;

    return [$x, $ymax - $y];
}

#####
#
#   read_timestamp
#
#####
sub read_timestamp {
    return read_byte() * 20;
}

#####
#
#   emit_header
#
#####
sub emit_header {
    my $data;

    read INPUT, $data, 40;

    my ($id, $version, $width, $height, $page_type) =
        unpack("A32CSSC", $data);

    print STDOUT <<EOF;
<svg viewBox="0 0 $width $height" fill="none" stroke="black" stroke-width="10" stroke-linecap="round" stroke-linejoin="round">
    <rect width="$width" height="$height" fill="aliceblue"/>
EOF
    emit_comment("id = $id");
    emit_comment("version = $version");
    emit_comment("width = $width");
    emit_comment("height = $height");
    emit_comment("page type = $page_type");

    return $height;
}

#####
#
#   emit_comment
#
#####
sub emit_comment {
    my $message = shift;
    
    print STDOUT "    <!-- $message -->\n";
}

#####
#
#   emit_polyline
#
#####
sub emit_polyline {
    my $coords = shift;
    my @points = map {
        $_->[0] . "," . $_->[1];
    } @$coords;
    my $data = join(" ", @points);

    print STDOUT <<EOF;
    <polyline points="$data"/>
EOF
}

#####
#
#   emit_footer
#
#####
sub emit_footer {
    print STDOUT <<EOF;
</svg>
EOF
}
