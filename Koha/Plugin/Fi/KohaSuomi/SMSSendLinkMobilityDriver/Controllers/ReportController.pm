package Koha::Plugin::Fi::KohaSuomi::SMSSendLinkMobilityDriver::Controllers::ReportController;

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;

use Mojo::Base 'Mojolicious::Controller';
use Try::Tiny;
use Koha::Notice::Messages;

=head1 API

=cut

sub set {
    my $c = shift->openapi->valid_input or return;

    my $message_id = $c->validation->param('message_id');
    my $status = $c->validation->param('status');
    my $delivery_note = $c->validation->param('message');
    my $notice;

    return try {
        $notice = Koha::Notice::Messages->find($message_id);

        if ($status eq "ERROR") {
            # Delivery was failed. Set notice status to failed and add delivery
            # note provided by Labyrintti.
            $notice->set({
                status        => 'failed',
                delivery_note => $delivery_note,
            })->store;
        }
        return $c->render(status => 200, openapi => "");
    }
    catch {
        unless ($notice) {
            return $c->render( status  => 404,
                               openapi => { error => "Notice not found" } );
        } else {
            return $c->render( status  => 500,
                               openapi => { error => "Something went wrong, check the logs!" } );
        }
    };
}

1;