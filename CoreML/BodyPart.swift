

import Foundation

class BodyPart {
    
    var uidx: String
    var partIdx: Int
    var x: CGFloat
    var y: CGFloat
    var score: Double
    
    init(_ uidx: String,_ partIdx: Int,_ x: CGFloat,_ y: CGFloat,_ score: Double){
        self.uidx = uidx
        self.partIdx = partIdx
        self.x = x
        self.y = y
        self.score = score
    }
}
