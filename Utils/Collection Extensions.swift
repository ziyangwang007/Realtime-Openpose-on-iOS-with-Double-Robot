

import Foundation

extension Array where Iterator.Element == CGFloat {
    var average: CGFloat? {
        guard !isEmpty else {
            return nil
        }
        
        var ret = self.reduce(CGFloat(0)) { (cur, next) -> CGFloat in
            var cur = cur
            cur += next
            return cur
        }
        let fcount = CGFloat(count)
        ret /= fcount
        return ret
    }
}
