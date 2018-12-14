test "" {
    var data: ?[*]const u8 = ""[0..].ptr;
    @import("std").debug.assert(data != null);
}
