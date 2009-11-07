###
### class.nqp: Figure out how to write accessors and a custom new() method
###

# TO USE:
#   $ nqp class.nqp


class Foo {
    has $!name;

    method new(:$name) {
        my $class := pir::getattribute__PPs(self.HOW, "parrotclass");
        Q:PIR{ $P0  = find_lex '$class'
               self = new $P0           };

        $!name := $name;

        self;
    }

    method name ($name?) {
        $!name := $name // $!name;
    }
}

my $foo := Foo.new(:name('bar'));
say($foo.name);

$foo.name('quux');
say($foo.name);
