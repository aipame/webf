interface DOMMatrixReadonly {
    readonly is2D: DartImpl<boolean>;
    readonly isIdentity: DartImpl<boolean>;
    m11: number;
    m12: number;
    m13: number;
    m14: number;
    m21: number;
    m22: number;
    m23: number;
    m24: number;
    m31: number;
    m32: number;
    m33: number;
    m34: number;
    m41: number;
    m42: number;
    m43: number;
    m44: number;
    a: number;
    b: number;
    c: number;
    d: number;
    e: number;
    f: number;
    flipX(): DOMMatrix;
    flipY(): DOMMatrix;
    inverse(): DOMMatrix;
    multiply(matrix: DOMMatrix | double[]): DOMMatrix;
    rotateAxisAngle(x:number, y:number, z:number, angle:number): DOMMatrix;
    rotate(rotX:number, rotY:number, rotZ:number): DOMMatrix;
    rotateFromVector(x:number, y:number): DOMMatrix;
    scale(scaleX: number, scaleY: number, scaleZ: number, originX: number, originY: number, originZ: number): DOMMatrix;
    scale3d(scale: number, originX: number, originY: number, originZ: number): DOMMatrix;
    // TODO
    // scaleNonUniform(): DOMMatrix;
    skewX(sx: number): DOMMatrix;
    skewY(sy: number): DOMMatrix;
    // toFloat32Array(): number[];
    // toFloat64Array(): number[];
    // TODO
    // toJSON(): DartImpl<JSON>;
    toString(): string;
    // TODO DOMPoint
    // transformPoint(): DartImpl<DOMPoint>;
    translate(tx:number, ty:number, tz:number): DOMMatrix;
    // fromFloat32Array(): StaticMethod<DOMMatrix>;
    // fromFloat64Array(): StaticMethod<DOMMatrix>;
    // fromMatrix(): StaticMethod<DOMMatrix>;
    new(init?: number[]): DOMMatrixReadonly;
}