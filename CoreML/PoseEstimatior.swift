//
//  PoseEstimation.swift
//  iOSOpenPose
//
//  Created by Eugene Bokhan on 1/19/18.
//  Copyright © 2018 Eugene Bokhan. All rights reserved.
//

import Foundation


struct Connection {
    var score: Double
    var idx1: Int
    var idx2: Int
    var partIdx1: Int
    var partIdx2: Int
    var coord1: (CGFloat,CGFloat)
    var coord2: (CGFloat,CGFloat)
    var score1: Double
    var score2: Double
    
    init(score: Double,
         partIdx1: Int,partIdx2: Int,
         idx1: Int,idx2: Int,
         coord1: (CGFloat,CGFloat),coord2:(CGFloat,CGFloat),
         score1: Double,score2: Double) {
        self.score = score
        self.score1 = score1
        self.score2 = score2
        self.coord1 = coord1
        self.coord2 = coord2
        self.idx1 = idx1
        self.idx2 = idx2
        self.partIdx1 = partIdx1
        self.partIdx2 = partIdx2
    }
}

class PoseEstimator {
    
    let openCVWrapper = OpenCVWrapper()
    
    var heatRows = 0
    var heatColumns = 0
    
    let nmsThreshold = 0.1
    let localPAFThreshold = 0.1
    let pafCountThreshold = 5
    let partCountThreshold = 4.0
    let partScoreThreshold = 0.6
    
    init(_ imageWidth: Int,_ imageHeight: Int){
        heatRows = imageWidth / 8
        heatColumns = imageHeight / 8
    }
    
    func estimate (_ mm: Array<Double>) -> [Human] {
        let startTime4 = CFAbsoluteTimeGetCurrent()
        
        let separateLen = 19*heatRows*heatColumns
        let pafMat = Matrix<Double>(rows: 38, columns: heatRows*heatColumns,
                                    elements: Array<Double>(mm[separateLen..<mm.count]))
        
        var data = Array<Double>(mm[0..<separateLen])
        openCVWrapper.matrixMin (&data,
                                 data_size: Int32(data.count),
                                 data_rows: 19,
                                 heat_rows: Int32(heatRows)
        )
        
        let heatMat = Matrix<Double>(rows: 19, columns: heatRows*heatColumns, elements: data )
        
        let timeElapsed4 = CFAbsoluteTimeGetCurrent() - startTime4
        print("init elapsed for \(timeElapsed4) seconds")
        
        let startTime3 = CFAbsoluteTimeGetCurrent()
        
        var _nmsThreshold = max(mean(data) * 4.0, nmsThreshold)
        _nmsThreshold = min(_nmsThreshold, 0.3)
        print(_nmsThreshold)
        
        var coords = [[(Int,Int)]]()
        for i in 0..<heatMat.rows-1 {
            var nms = Array<Double>(heatMat.row(i))
            nonMaxSuppression(&nms, dataRows: Int32(heatColumns),
                              maskSize: 5, threshold: _nmsThreshold)
            let c = nms.enumerated().filter{ $0.1 > _nmsThreshold }.map { x in
                return ( x.0 / heatRows , x.0 % heatRows )
            }
            coords.append(c)
        }
        
        var pairsByConn = [Connection]()
        for ((partIdx1, partIdx2), (pafXIdx, pafYIdx)) in zip(CocoPairs, CocoPairsNetwork){
            let pairs = scorePairs(
                partIdx1, partIdx2,
                coords[partIdx1], coords[partIdx2],
                Array<Double>(pafMat.row(pafXIdx)), Array<Double>(pafMat.row(pafYIdx)),
                &data,
                rescale: (1.0 / CGFloat(heatColumns), 1.0 / CGFloat(heatRows))
            )
            pairsByConn.append(contentsOf: pairs)
        }
        
        var humans = pairsByConn.map{ Human([$0]) }
        if humans.count == 0 {
            return humans
        }
        
        let timeElapsed3 = CFAbsoluteTimeGetCurrent() - startTime3
        print("others elapsed for \(timeElapsed3) seconds")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        while true {
            var items: (Int,Human,Human)!
            for x in combinations([[Int](0..<humans.count), [Int](1..<humans.count)]){
                if x[0] == x[1] {
                    continue
                }
                let k1 = humans[x[0]]
                let k2 = humans[x[1]]
                
                if k1.isConnected(k2){
                    items = (x[1],k1,k2)
                    break
                }
            }
            
            if items != nil {
                items.1.merge(items.2)
                humans.remove(at: items.0)
            } else {
                break
            }
        }
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        print("human_roop Time elapsed for roop: \(timeElapsed) seconds")
        
        // reject by subset count
        humans = humans.filter{ $0.partCount() >= pafCountThreshold }
        
        // reject by subset max score
        humans = humans.filter{ $0.getMaxScore() >= partScoreThreshold }
        
        return humans
    }
    
    func combinations<T>(_ arr: [[T]]) -> [[T]] {
        return arr.reduce([[]]) {
            var x = [[T]]()
            for elem1 in $0 {
                for elem2 in $1 {
                    x.append(elem1 + [elem2])
                }
            }
            return x
        }
    }
    
    func nonMaxSuppression(_ data: inout [Double],
                           dataRows: Int32,
                           maskSize: Int32,
                           threshold: Double) {
        
        openCVWrapper.maximum_filter(&data,
                                     data_size: Int32(data.count),
                                     data_rows: dataRows,
                                     mask_size: maskSize,
                                     threshold: threshold)
    }
    
    func getScore(_ x1 : Int,_ y1: Int,_ x2: Int,_ y2: Int,_ pafMatX: [Double],_ pafMatY: [Double]) -> (Double,Int) {
        let __numInter = 10
        let __numInterF = Double(__numInter)
        let dx = Double(x2 - x1)
        let dy = Double(y2 - y1)
        let normVec = sqrt(pow(dx,2) + pow(dy,2))
        
        if normVec < 1e-4 {
            return (0.0, 0)
        }
        let vx = dx / normVec
        let vy = dy / normVec
        var xs : [Double]
        
        if x1 == x2 {
            xs = Array<Double>(repeating: Double(x1) , count: __numInter)
        } else {
            xs = stride(from: Double(x1), to: Double(x2), by: Double(dx / __numInterF)).map {$0}
        }
        var ys : [Double]
        if y1 == y2 {
            ys = Array<Double>(repeating: Double(y1) , count: __numInter)
        } else {
            ys = stride(from: Double(y1), to: Double(y2), by: Double(dy / __numInterF)).map {$0}
        }
        let xs2 = xs.map{ Int($0+0.5) }
        let ys2 = ys.map{ Int($0+0.5) }
        
        var pafXs : [Double] = Array(repeating: 0.0 , count: __numInter)
        var pafYs : [Double] = Array(repeating: 0.0 , count: __numInter)
        for (idx, (mx, my)) in zip(xs2, ys2).enumerated() {
            pafXs[idx] = pafMatX[my*heatRows+mx]
            pafYs[idx] = pafMatY[my*heatRows+mx]
        }
        
        let localScores = pafXs * vx + pafYs * vy
        var thidxs = localScores.filter({$0 > localPAFThreshold})
        
        if (thidxs.count > 0){
            thidxs[0] = 0.0
        }
        return (sum(thidxs), thidxs.count)
    }
    
    func scorePairs(_ partIdx1: Int,_ partIdx2: Int,
                    _ coordList1: [(Int,Int)],_ coordList2: [(Int,Int)],
                    _ pafMatX: [Double],_ pafMatY: [Double],
                    _ heatmap: inout [Double],
                    rescale: (CGFloat,CGFloat) = (1.0, 1.0)) -> [Connection] {
        
        var connectionTmp = [Connection]()
        for (idx1,(y1,x1)) in coordList1.enumerated() {
            for (idx2,(y2,x2)) in coordList2.enumerated() {
                let (score, count) = getScore(x1, y1, x2, y2, pafMatX, pafMatY)
                if count < pafCountThreshold || score <= 0.0 {
                    continue
                }
                
                connectionTmp.append(Connection(
                    score: score,
                    partIdx1: partIdx1, partIdx2: partIdx2,
                    idx1: idx1, idx2: idx2,
                    coord1: (CGFloat(x1) * rescale.0, CGFloat(y1) * rescale.1),
                    coord2: (CGFloat(x2) * rescale.0, CGFloat(y2) * rescale.1),
                    score1: heatmap[partIdx1*y1*x1],
                    score2: heatmap[partIdx2*y2*x2]
                ))
            }
        }
        
        var connection = [Connection]()
        // Multiple score cuts
        var usedIdx1 = [Int]()
        var usedIdx2 = [Int]()
        connectionTmp.sorted{ $0.score > $1.score }.forEach { conn in
            
            if usedIdx1.contains(conn.idx1) || usedIdx2.contains(conn.idx2) {
                return
            }
            connection.append(conn)
            usedIdx1.append(conn.idx1)
            usedIdx2.append(conn.idx2)
        }
        return connection
    }
}

