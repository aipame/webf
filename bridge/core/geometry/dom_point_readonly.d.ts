interface DOMPointReadonly {
    x: number;
    y: number;
    z: number;
    w: number;
    matrixTransform(matrix: DOMMatrix): DOMPoint;
    new(x?: number, y?:number, z?:number, w?:number): DOMPointReadonly;
}