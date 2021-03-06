///<reference path="../../../d.ts/console.d.ts" />
///<reference path="../../../d.ts/node.d.ts" />
export class CallbacksConsumer  {
    static asyncMethod(param: string, callback: (param: string) => void) {
        return setTimeout((() => callback(param + param)), 0);
    }
}

export class CallbacksProducer  {
    static callback(param: string) {
        return console.log(param);
    }
}

CallbacksConsumer.asyncMethod("foo", CallbacksProducer.callback);
