//
//  GraphView.swift
//  SWFShapeDraw
//
//  Created by larryhou on 22/8/2015.
//  Copyright © 2015 larryhou. All rights reserved.
//

import Foundation
import UIKit

class GraphView:UIView
{
    struct GraphicsState:OptionSetType
    {
        let rawValue:Int
        init(rawValue:Int) { self.rawValue = rawValue }
        
        static let SolidStroke    = GraphicsState(rawValue: 1 << 0)
        static let GradientStroke = GraphicsState(rawValue: 1 << 1)
        static let SolidFill      = GraphicsState(rawValue: 1 << 2)
        static let GradientFill   = GraphicsState(rawValue: 1 << 3)
        
        static let Stroke:GraphicsState = [GraphicsState.SolidStroke, GraphicsState.GradientStroke]
        static let Fill:GraphicsState   = [GraphicsState.SolidFill,   GraphicsState.GradientFill]
    }
    
    struct GradientStyle
    {
        var type:String
        var gradient:CGGradient
        var matrix:(a:CGFloat, b:CGFloat, c:CGFloat, d:CGFloat, tx:CGFloat, ty:CGFloat)
        var focalPointRatio:CGFloat
    }
    
    private var state:GraphicsState!
    private var queue:[(method:String, params:NSDictionary)] = []
    
    private var path:CGMutablePath!
    private var style:NSDictionary!
    
    private var lineWidth:CGFloat = 1.0
    private var lineCap = CGLineCap.Round
    private var lineJoin = CGLineJoin.Round
    private var miterLimit:CGFloat = 3.0
    
    func doStep(method:String, params:NSDictionary)
    {
        queue.append((method, params))
    }
    
    func getGradientStyle(params:NSDictionary) -> GradientStyle
    {
        let type = params.valueForKey("type") as! String
        let colors = params.valueForKey("colors") as! [Int]
        let alphas = params.valueForKey("alphas") as! [Double]
        
        var rgbaColors:[CGColor] = []
        for i in 0..<colors.count
        {
            let rgbColor = colors[i]
            let b = (rgbColor >> 00) & 0xFF
            let g = (rgbColor >> 08) & 0xFF
            let r = (rgbColor >> 16) & 0xFF
            let color = UIColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(alphas[i])).CGColor
            rgbaColors.append(color)
        }
        
        let ratios = params.valueForKey("ratios") as! [Int]
        var locations = ratios.map({ CGFloat($0) / 0xFF })
        
        let gradient = CGGradientCreateWithColors(CGColorSpaceCreateDeviceRGB(), rgbaColors, &locations)
        
        var matrix:(a:CGFloat, b:CGFloat, c:CGFloat, d:CGFloat, tx:CGFloat, ty:CGFloat) = (0,0,0,0,0,0)
        matrix.a = CGFloat(params.valueForKeyPath("matrix.a") as! Double)
        matrix.b = CGFloat(params.valueForKeyPath("matrix.b") as! Double)
        matrix.c = CGFloat(params.valueForKeyPath("matrix.c") as! Double)
        matrix.d = CGFloat(params.valueForKeyPath("matrix.d") as! Double)
        matrix.tx = CGFloat(params.valueForKeyPath("matrix.tx") as! Double)
        matrix.ty = CGFloat(params.valueForKeyPath("matrix.ty") as! Double)
        
        let focalPointRatio = CGFloat(params.valueForKey("focalPointRatio") as! Double)
        return GradientStyle(type: type, gradient: gradient!, matrix: matrix, focalPointRatio: focalPointRatio)
    }
    
    func getCoord(params:NSDictionary, key:String) -> CGFloat
    {
        if let data = getUnifyValue(params, key: key)
        {
            return CGFloat(data as! Double)
            
        }
        
        return 0.0
    }
    
    func getColor(params:NSDictionary, colorKey:String, alphaKey:String) -> UIColor
    {
        let rgbColor:Int
        if let data = getUnifyValue(params, key: colorKey)
        {
            rgbColor = data as! Int
        }
        else
        {
            rgbColor = 0
        }
        
        let b = (rgbColor >> 00) & 0xFF
        let g = (rgbColor >> 08) & 0xFF
        let r = (rgbColor >> 16) & 0xFF
        
        let a:CGFloat
        if let data = getUnifyValue(params, key: alphaKey)
        {
            a = CGFloat(data as! Double)
        }
        else
        {
            a = 1.0
        }
        
        let color = UIColor(red: CGFloat(r)/0xFF, green: CGFloat(g)/0xFF, blue: CGFloat(b)/0xFF, alpha: a)
        return color
    }
    
    override func drawRect(rect: CGRect)
    {
        let context = UIGraphicsGetCurrentContext()
        
        for i in 0..<queue.count
        {
            let step = queue[i]
            drawByStep(context, step: step)
        }
        
        tryStrokeContextPath(context)
    }
    
    func drawByStep(context:CGContext?, step:(method:String, params:NSDictionary))
    {
        let params = step.params
        switch step.method
        {
            case "LINE_STYLE":
                tryStrokeContextPath(context)
                
                state = GraphicsState.SolidStroke
                style = params
                
                path = CGPathCreateMutable()
                print("// LINE STYLE -> NEW PATH")
            
            case "LINE_GRADIENT_STYLE":
                tryStrokeContextPath(context)
                
                state = GraphicsState.GradientStroke
                style = params
                
                path = CGPathCreateMutable()
                print("// LINE GRADIENT STYLE -> NEW PATH")
                
            case "LINE_TO":
                CGPathAddLineToPoint(path, nil,
                    getCoord(params, key: "x"), getCoord(params, key: "y"))
                print(String(format:"CGPathAddLineToPoint(path, nil, %6.2f, %6.2f)", getCoord(params, key: "x"), getCoord(params, key: "y")))
            
            case "MOVE_TO":
                CGPathMoveToPoint(path, nil,
                    getCoord(params, key: "x"), getCoord(params, key: "y"))
                print(String(format:"CGPathMoveToPoint(path, nil, %6.2f, %6.2f)", getCoord(params, key: "x"), getCoord(params, key: "y")))
            
            case "CURVE_TO":
                CGPathAddQuadCurveToPoint(path, nil,
                    getCoord(params, key: "controlX"), getCoord(params, key: "controlY"),
                    getCoord(params, key: "anchorX"),  getCoord(params, key: "anchorY"))
                print(String(format:"CGPathAddQuadCurveToPoint(path, nil, %6.2f, %6.2f, %6.2f, %6.2f)",
                    getCoord(params, key: "controlX"), getCoord(params, key: "controlY"),
                    getCoord(params, key: "anchorX"),  getCoord(params, key: "anchorY")))
                
            case "BEGIN_FILL":
                tryStrokeContextPath(context)
                
                state = GraphicsState.SolidFill
                style = params
                
                path = CGPathCreateMutable()
                print("// BEGIN FILL -> NEW PATH")
            
            case "BEGIN_GRADIENT_FILL":
                tryStrokeContextPath(context)
                
                state = GraphicsState.GradientFill
                style = params
                
                path = CGPathCreateMutable()
                print("// BEGIN GRADIENT FILL -> NEW PATH")
            
            case "END_FILL":
                if state == GraphicsState.GradientFill
                {
                    print("// END FILL GRADIENT")
                    CGContextAddPath(context, path)
                    CGContextClip(context)
                    fillContextGradientStyle(context, params: style)
                    style = nil
                }
                else
                {
                    print("// END FILL SOLID")
                    CGContextAddPath(context, path)
                    CGContextSetFillColorWithColor(context, getColor(style, colorKey: "color", alphaKey: "alpha").CGColor)
                    CGContextFillPath(context)
                }
                
                path = nil
                
            default:break
        }
    }
    
    func tryStrokeContextPath(context:CGContext?)
    {
        if path != nil && state != nil && GraphicsState.Stroke.contains(state)
        {
            if (state == GraphicsState.GradientStroke)
            {
                print("// STROKE GRADIENT")
                strokePathWithGradientStyle(context, path: path)
            }
            else
            {
                print("// STROKE SOLID")
                CGContextAddPath(context, path)
                print("CGContextAddPath(context, path)")
                setContextLineSolidColorStyle(context, params: style)
                CGContextStrokePath(context)
                print("CGContextStrokePath(context)")
            }
            
            path = nil
        }
    }
    
    func setContextLineSolidColorStyle(context:CGContext?, params:NSDictionary)
    {
        let r:Int, g:Int, b:Int
        if let data = getUnifyValue(params, key: "color")
        {
            let rgbColor = data as! Int
            b = (rgbColor >> 00) & 0xFF
            g = (rgbColor >> 08) & 0xFF
            r = (rgbColor >> 16) & 0xFF
        }
        else
        {
            r = 0; g = 0; b = 0
        }
        
        var a:CGFloat = 1.0
        if let data = getUnifyValue(params, key: "alpha")
        {
            a = CGFloat(data as! Double)
        }
        
        let color = UIColor(red: CGFloat(r)/0xFF, green: CGFloat(g)/0xFF, blue: CGFloat(b)/0xFF, alpha: a)
        CGContextSetStrokeColorWithColor(context, color.CGColor)
        print(String(format: "CGContextSetStrokeColorWithColor(context, UIColor(red:%.2f, green:%.2f, blue:%.2f, alpha:%.2f).CGColor)", CGFloat(r)/0xFF, CGFloat(g)/0xFF, CGFloat(b)/0xFF, a))
        
        if let data = getUnifyValue(params, key: "thickness")
        {
            lineWidth = CGFloat(data as! Double)
        }
        else
        {
            lineWidth = 0.0
        }
        
        CGContextSetLineWidth(context, lineWidth)
        print(String(format: "CGContextSetLineWidth(context, %.1f)", lineWidth))
        
        if let data = getUnifyValue(params, key: "caps")
        {
            let type = data as! String
            switch type
            {
                case "square": lineCap = CGLineCap.Square
                case "round": lineCap = CGLineCap.Round
                default: lineCap = CGLineCap.Butt
            }
        }
        else
        {
            lineCap = CGLineCap.Butt
        }
        
        CGContextSetLineCap(context, lineCap)
        print(String(format: "CGContextSetLineCap(context, CGLineCap(rawValue:%d)!)", lineCap.rawValue))
        
        if let data = getUnifyValue(params, key: "joints")
        {
            let type = data as! String
            switch type
            {
                case "bevel": lineJoin = CGLineJoin.Bevel
                case "miter": lineJoin = CGLineJoin.Miter
                case "round":fallthrough
                default:lineJoin = CGLineJoin.Round
            }
        }
        else
        {
            lineJoin = CGLineJoin.Round
        }
        
        CGContextSetLineJoin(context, lineJoin)
        print(String(format: "CGContextSetLineJoin(context, CGLineJoin(rawValue:%d)!)", lineJoin.rawValue))
        
        if let data = getUnifyValue(params, key: "miterLimit")
        {
            miterLimit = CGFloat(data as! Double)
        }
        else
        {
            miterLimit = 3.0
        }
        
        CGContextSetMiterLimit(context, miterLimit)
        print(String(format: "CGContextSetMiterLimit(context, %.1f)", miterLimit))
    }
    
    func getUnifyValue(params:NSDictionary, key:String) -> AnyObject?
    {
        let data = params.valueForKey(key)
        if let data = data where data is NSNull
        {
            return nil
        }
        
        return data
    }
    
    func strokePathWithGradientStyle(context:CGContext?, path:CGMutablePath)
    {
        let gradientPath = CGPathCreateCopyByStrokingPath(path, nil, lineWidth, lineCap, lineJoin, miterLimit)
        CGContextAddPath(context, gradientPath)
        CGContextClip(context)
        
        fillContextGradientStyle(context, params: style)
    }
    
    func fillContextGradientStyle(context:CGContext?, params:NSDictionary)
    {
        let style = getGradientStyle(params)
        let matrix = style.matrix
        
        let angle = atan2(matrix.b, matrix.a)
        let scaleX = matrix.a / cos(angle)
        let scaleY = matrix.d / cos(angle)
        
        let width = scaleX * 1638.4, height = scaleY * 1638.4
        print(angle / CGFloat(M_PI) * 180)
        
        if style.type == "radial"
        {
            if width != height
            {
                //TODO: 椭圆情况做变形处理
            }
            
            let endRadius = max(width / 2, height / 2);
            let startCenter = CGPointMake(width / 2 * cos(angle) * style.focalPointRatio + matrix.tx,
                                         height / 2 * sin(angle) * style.focalPointRatio + matrix.ty)
            let endCenter = CGPointMake(matrix.tx, matrix.ty)
            
            CGContextDrawRadialGradient(context, style.gradient, startCenter, 0, endCenter, endRadius, CGGradientDrawingOptions(rawValue: 0))
        }
        else
        {
            let sp = CGPointMake(-819.2 * scaleX, 0)
            let startPoint = CGPointMake(sp.x * cos(angle) - sp.y * sin(angle) + matrix.tx,
                                         sp.x * sin(angle) + sp.y * cos(angle) + matrix.ty)
            let ep = CGPointMake( 819.2 * scaleX, 0)
            let endPoint = CGPointMake(ep.x * cos(angle) - ep.y * sin(angle) + matrix.tx,
                                       ep.x * sin(angle) + ep.y * cos(angle) + matrix.ty)
            
            CGContextDrawLinearGradient(context, style.gradient, startPoint, endPoint, CGGradientDrawingOptions(rawValue: 0))
        }
    }
}
