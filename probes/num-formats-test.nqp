###
### num-formats-test.nqp: Test inline PIR number formats
###

# TO USE:
#   $ parrot_nqp num-formats-test.nqp


say(Q:PIR{ %r = box 0o777 });
say(Q:PIR{ %r = box 0x1FF });
say(Q:PIR{ %r = box 511   });
