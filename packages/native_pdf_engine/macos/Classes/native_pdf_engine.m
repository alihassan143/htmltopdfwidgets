#include <stdint.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import "../../tool/macos_headers.h"

#if !__has_feature(objc_arc)
#error "This file must be compiled with ARC enabled"
#endif

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"

typedef struct {
  int64_t version;
  void* (*newWaiter)(void);
  void (*awaitWaiter)(void*);
  void* (*currentIsolate)(void);
  void (*enterIsolate)(void*);
  void (*exitIsolate)(void);
  int64_t (*getMainPortId)(void);
  bool (*getCurrentThreadOwnsIsolate)(int64_t);
} DOBJC_Context;

id objc_retainBlock(id);

#define BLOCKING_BLOCK_IMPL(ctx, BLOCK_SIG, INVOKE_DIRECT, INVOKE_LISTENER)    \
  assert(ctx->version >= 1);                                                   \
  void* targetIsolate = ctx->currentIsolate();                                 \
  int64_t targetPort = ctx->getMainPortId == NULL ? 0 : ctx->getMainPortId();  \
  return BLOCK_SIG {                                                           \
    void* currentIsolate = ctx->currentIsolate();                              \
    bool mayEnterIsolate =                                                     \
        currentIsolate == NULL &&                                              \
        ctx->getCurrentThreadOwnsIsolate != NULL &&                            \
        ctx->getCurrentThreadOwnsIsolate(targetPort);                          \
    if (currentIsolate == targetIsolate || mayEnterIsolate) {                  \
      if (mayEnterIsolate) {                                                   \
        ctx->enterIsolate(targetIsolate);                                      \
      }                                                                        \
      INVOKE_DIRECT;                                                           \
      if (mayEnterIsolate) {                                                   \
        ctx->exitIsolate();                                                    \
      }                                                                        \
    } else {                                                                   \
      void* waiter = ctx->newWaiter();                                         \
      INVOKE_LISTENER;                                                         \
      ctx->awaitWaiter(waiter);                                                \
    }                                                                          \
  };


typedef BOOL  (^_ProtocolTrampoline)(void * sel);
__attribute__((visibility("default"))) __attribute__((used))
BOOL  _NativeLibrary_protocolTrampoline_e3qsqz(id target, void * sel) {
  return ((_ProtocolTrampoline)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel);
}

typedef void  (^_ListenerTrampoline)(void * arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline _NativeLibrary_wrapListenerBlock_18v1jvf(_ListenerTrampoline block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1) {
    objc_retainBlock(block);
    block(arg0, (__bridge id)(__bridge_retained void*)(arg1));
  };
}

typedef void  (^_BlockingTrampoline)(void * waiter, void * arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline _NativeLibrary_wrapBlockingBlock_18v1jvf(
    _BlockingTrampoline block, _BlockingTrampoline listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(void * arg0, id arg1), {
    objc_retainBlock(block);
    block(nil, arg0, (__bridge id)(__bridge_retained void*)(arg1));
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, arg0, (__bridge id)(__bridge_retained void*)(arg1));
  });
}

typedef void  (^_ProtocolTrampoline_1)(void * sel, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeLibrary_protocolTrampoline_18v1jvf(id target, void * sel, id arg1) {
  return ((_ProtocolTrampoline_1)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1);
}

typedef id  (^_ProtocolTrampoline_2)(void * sel, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
id  _NativeLibrary_protocolTrampoline_xr62hr(id target, void * sel, id arg1) {
  return ((_ProtocolTrampoline_2)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1);
}

typedef void  (^_ListenerTrampoline_1)(void * arg0, struct objc_selector * arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_1 _NativeLibrary_wrapListenerBlock_be1lg6(_ListenerTrampoline_1 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, struct objc_selector * arg1) {
    objc_retainBlock(block);
    block(arg0, arg1);
  };
}

typedef void  (^_BlockingTrampoline_1)(void * waiter, void * arg0, struct objc_selector * arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_1 _NativeLibrary_wrapBlockingBlock_be1lg6(
    _BlockingTrampoline_1 block, _BlockingTrampoline_1 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(void * arg0, struct objc_selector * arg1), {
    objc_retainBlock(block);
    block(nil, arg0, arg1);
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, arg0, arg1);
  });
}

typedef void  (^_ProtocolTrampoline_3)(void * sel, struct objc_selector * arg1);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeLibrary_protocolTrampoline_be1lg6(id target, void * sel, struct objc_selector * arg1) {
  return ((_ProtocolTrampoline_3)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1);
}

typedef id  (^_ProtocolTrampoline_4)(void * sel);
__attribute__((visibility("default"))) __attribute__((used))
id  _NativeLibrary_protocolTrampoline_1mbt9g9(id target, void * sel) {
  return ((_ProtocolTrampoline_4)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel);
}

typedef NSDragOperation  (^_ProtocolTrampoline_5)(void * sel, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
NSDragOperation  _NativeLibrary_protocolTrampoline_u1rw1h(id target, void * sel, id arg1) {
  return ((_ProtocolTrampoline_5)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1);
}

typedef BOOL  (^_ProtocolTrampoline_6)(void * sel, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
BOOL  _NativeLibrary_protocolTrampoline_3su7tt(id target, void * sel, id arg1) {
  return ((_ProtocolTrampoline_6)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1);
}

typedef struct CGRect  (^_ProtocolTrampoline_7)(void * sel);
__attribute__((visibility("default"))) __attribute__((used))
struct CGRect  _NativeLibrary_protocolTrampoline_1c3uc0w(id target, void * sel) {
  return ((_ProtocolTrampoline_7)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel);
}

typedef void  (^_ListenerTrampoline_2)(void * arg0, BOOL arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_2 _NativeLibrary_wrapListenerBlock_10lndml(_ListenerTrampoline_2 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, BOOL arg1) {
    objc_retainBlock(block);
    block(arg0, arg1);
  };
}

typedef void  (^_BlockingTrampoline_2)(void * waiter, void * arg0, BOOL arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_2 _NativeLibrary_wrapBlockingBlock_10lndml(
    _BlockingTrampoline_2 block, _BlockingTrampoline_2 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(void * arg0, BOOL arg1), {
    objc_retainBlock(block);
    block(nil, arg0, arg1);
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, arg0, arg1);
  });
}

typedef void  (^_ProtocolTrampoline_8)(void * sel, BOOL arg1);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeLibrary_protocolTrampoline_10lndml(id target, void * sel, BOOL arg1) {
  return ((_ProtocolTrampoline_8)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1);
}

typedef void  (^_ListenerTrampoline_3)(void * arg0, struct CGRect arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_3 _NativeLibrary_wrapListenerBlock_1e49sma(_ListenerTrampoline_3 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, struct CGRect arg1) {
    objc_retainBlock(block);
    block(arg0, arg1);
  };
}

typedef void  (^_BlockingTrampoline_3)(void * waiter, void * arg0, struct CGRect arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_3 _NativeLibrary_wrapBlockingBlock_1e49sma(
    _BlockingTrampoline_3 block, _BlockingTrampoline_3 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(void * arg0, struct CGRect arg1), {
    objc_retainBlock(block);
    block(nil, arg0, arg1);
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, arg0, arg1);
  });
}

typedef void  (^_ProtocolTrampoline_9)(void * sel, struct CGRect arg1);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeLibrary_protocolTrampoline_1e49sma(id target, void * sel, struct CGRect arg1) {
  return ((_ProtocolTrampoline_9)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1);
}

typedef struct CGPoint  (^_ProtocolTrampoline_10)(void * sel);
__attribute__((visibility("default"))) __attribute__((used))
struct CGPoint  _NativeLibrary_protocolTrampoline_7ohnx8(id target, void * sel) {
  return ((_ProtocolTrampoline_10)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel);
}

typedef void  (^_ListenerTrampoline_4)(void * arg0, struct CGPoint arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_4 _NativeLibrary_wrapListenerBlock_1bktu2(_ListenerTrampoline_4 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, struct CGPoint arg1) {
    objc_retainBlock(block);
    block(arg0, arg1);
  };
}

typedef void  (^_BlockingTrampoline_4)(void * waiter, void * arg0, struct CGPoint arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_4 _NativeLibrary_wrapBlockingBlock_1bktu2(
    _BlockingTrampoline_4 block, _BlockingTrampoline_4 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(void * arg0, struct CGPoint arg1), {
    objc_retainBlock(block);
    block(nil, arg0, arg1);
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, arg0, arg1);
  });
}

typedef void  (^_ProtocolTrampoline_11)(void * sel, struct CGPoint arg1);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeLibrary_protocolTrampoline_1bktu2(id target, void * sel, struct CGPoint arg1) {
  return ((_ProtocolTrampoline_11)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1);
}

typedef NSAccessibilityOrientation  (^_ProtocolTrampoline_12)(void * sel);
__attribute__((visibility("default"))) __attribute__((used))
NSAccessibilityOrientation  _NativeLibrary_protocolTrampoline_ua0zt4(id target, void * sel) {
  return ((_ProtocolTrampoline_12)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel);
}

typedef void  (^_ListenerTrampoline_5)(void * arg0, NSAccessibilityOrientation arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_5 _NativeLibrary_wrapListenerBlock_6qimxm(_ListenerTrampoline_5 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, NSAccessibilityOrientation arg1) {
    objc_retainBlock(block);
    block(arg0, arg1);
  };
}

typedef void  (^_BlockingTrampoline_5)(void * waiter, void * arg0, NSAccessibilityOrientation arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_5 _NativeLibrary_wrapBlockingBlock_6qimxm(
    _BlockingTrampoline_5 block, _BlockingTrampoline_5 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(void * arg0, NSAccessibilityOrientation arg1), {
    objc_retainBlock(block);
    block(nil, arg0, arg1);
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, arg0, arg1);
  });
}

typedef void  (^_ProtocolTrampoline_13)(void * sel, NSAccessibilityOrientation arg1);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeLibrary_protocolTrampoline_6qimxm(id target, void * sel, NSAccessibilityOrientation arg1) {
  return ((_ProtocolTrampoline_13)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1);
}

typedef NSAccessibilityUnits  (^_ProtocolTrampoline_14)(void * sel);
__attribute__((visibility("default"))) __attribute__((used))
NSAccessibilityUnits  _NativeLibrary_protocolTrampoline_1600k13(id target, void * sel) {
  return ((_ProtocolTrampoline_14)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel);
}

typedef void  (^_ListenerTrampoline_6)(void * arg0, NSAccessibilityUnits arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_6 _NativeLibrary_wrapListenerBlock_12prxo1(_ListenerTrampoline_6 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, NSAccessibilityUnits arg1) {
    objc_retainBlock(block);
    block(arg0, arg1);
  };
}

typedef void  (^_BlockingTrampoline_6)(void * waiter, void * arg0, NSAccessibilityUnits arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_6 _NativeLibrary_wrapBlockingBlock_12prxo1(
    _BlockingTrampoline_6 block, _BlockingTrampoline_6 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(void * arg0, NSAccessibilityUnits arg1), {
    objc_retainBlock(block);
    block(nil, arg0, arg1);
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, arg0, arg1);
  });
}

typedef void  (^_ProtocolTrampoline_15)(void * sel, NSAccessibilityUnits arg1);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeLibrary_protocolTrampoline_12prxo1(id target, void * sel, NSAccessibilityUnits arg1) {
  return ((_ProtocolTrampoline_15)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1);
}

typedef struct CGPoint  (^_ProtocolTrampoline_16)(void * sel, struct CGPoint arg1);
__attribute__((visibility("default"))) __attribute__((used))
struct CGPoint  _NativeLibrary_protocolTrampoline_loskaj(id target, void * sel, struct CGPoint arg1) {
  return ((_ProtocolTrampoline_16)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1);
}

typedef struct CGSize  (^_ProtocolTrampoline_17)(void * sel, struct CGSize arg1);
__attribute__((visibility("default"))) __attribute__((used))
struct CGSize  _NativeLibrary_protocolTrampoline_zeon27(id target, void * sel, struct CGSize arg1) {
  return ((_ProtocolTrampoline_17)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1);
}

typedef long  (^_ProtocolTrampoline_18)(void * sel);
__attribute__((visibility("default"))) __attribute__((used))
long  _NativeLibrary_protocolTrampoline_fai2e9(id target, void * sel) {
  return ((_ProtocolTrampoline_18)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel);
}

typedef void  (^_ListenerTrampoline_7)(void * arg0, long arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_7 _NativeLibrary_wrapListenerBlock_unr2j3(_ListenerTrampoline_7 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, long arg1) {
    objc_retainBlock(block);
    block(arg0, arg1);
  };
}

typedef void  (^_BlockingTrampoline_7)(void * waiter, void * arg0, long arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_7 _NativeLibrary_wrapBlockingBlock_unr2j3(
    _BlockingTrampoline_7 block, _BlockingTrampoline_7 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(void * arg0, long arg1), {
    objc_retainBlock(block);
    block(nil, arg0, arg1);
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, arg0, arg1);
  });
}

typedef void  (^_ProtocolTrampoline_19)(void * sel, long arg1);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeLibrary_protocolTrampoline_unr2j3(id target, void * sel, long arg1) {
  return ((_ProtocolTrampoline_19)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1);
}

typedef NSAccessibilityRulerMarkerType  (^_ProtocolTrampoline_20)(void * sel);
__attribute__((visibility("default"))) __attribute__((used))
NSAccessibilityRulerMarkerType  _NativeLibrary_protocolTrampoline_1sop3vw(id target, void * sel) {
  return ((_ProtocolTrampoline_20)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel);
}

typedef void  (^_ListenerTrampoline_8)(void * arg0, NSAccessibilityRulerMarkerType arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_8 _NativeLibrary_wrapListenerBlock_w4u4pi(_ListenerTrampoline_8 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, NSAccessibilityRulerMarkerType arg1) {
    objc_retainBlock(block);
    block(arg0, arg1);
  };
}

typedef void  (^_BlockingTrampoline_8)(void * waiter, void * arg0, NSAccessibilityRulerMarkerType arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_8 _NativeLibrary_wrapBlockingBlock_w4u4pi(
    _BlockingTrampoline_8 block, _BlockingTrampoline_8 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(void * arg0, NSAccessibilityRulerMarkerType arg1), {
    objc_retainBlock(block);
    block(nil, arg0, arg1);
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, arg0, arg1);
  });
}

typedef void  (^_ProtocolTrampoline_21)(void * sel, NSAccessibilityRulerMarkerType arg1);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeLibrary_protocolTrampoline_w4u4pi(id target, void * sel, NSAccessibilityRulerMarkerType arg1) {
  return ((_ProtocolTrampoline_21)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1);
}

typedef float  (^_ProtocolTrampoline_22)(void * sel);
__attribute__((visibility("default"))) __attribute__((used))
float  _NativeLibrary_protocolTrampoline_66c10j(id target, void * sel) {
  return ((_ProtocolTrampoline_22)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel);
}

typedef void  (^_ListenerTrampoline_9)(void * arg0, float arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_9 _NativeLibrary_wrapListenerBlock_1fcaigd(_ListenerTrampoline_9 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, float arg1) {
    objc_retainBlock(block);
    block(arg0, arg1);
  };
}

typedef void  (^_BlockingTrampoline_9)(void * waiter, void * arg0, float arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_9 _NativeLibrary_wrapBlockingBlock_1fcaigd(
    _BlockingTrampoline_9 block, _BlockingTrampoline_9 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(void * arg0, float arg1), {
    objc_retainBlock(block);
    block(nil, arg0, arg1);
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, arg0, arg1);
  });
}

typedef void  (^_ProtocolTrampoline_23)(void * sel, float arg1);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeLibrary_protocolTrampoline_1fcaigd(id target, void * sel, float arg1) {
  return ((_ProtocolTrampoline_23)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1);
}

typedef NSAccessibilitySortDirection  (^_ProtocolTrampoline_24)(void * sel);
__attribute__((visibility("default"))) __attribute__((used))
NSAccessibilitySortDirection  _NativeLibrary_protocolTrampoline_1gh8zj5(id target, void * sel) {
  return ((_ProtocolTrampoline_24)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel);
}

typedef void  (^_ListenerTrampoline_10)(void * arg0, NSAccessibilitySortDirection arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_10 _NativeLibrary_wrapListenerBlock_141m1k3(_ListenerTrampoline_10 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, NSAccessibilitySortDirection arg1) {
    objc_retainBlock(block);
    block(arg0, arg1);
  };
}

typedef void  (^_BlockingTrampoline_10)(void * waiter, void * arg0, NSAccessibilitySortDirection arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_10 _NativeLibrary_wrapBlockingBlock_141m1k3(
    _BlockingTrampoline_10 block, _BlockingTrampoline_10 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(void * arg0, NSAccessibilitySortDirection arg1), {
    objc_retainBlock(block);
    block(nil, arg0, arg1);
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, arg0, arg1);
  });
}

typedef void  (^_ProtocolTrampoline_25)(void * sel, NSAccessibilitySortDirection arg1);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeLibrary_protocolTrampoline_141m1k3(id target, void * sel, NSAccessibilitySortDirection arg1) {
  return ((_ProtocolTrampoline_25)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1);
}

typedef id  (^_ProtocolTrampoline_26)(void * sel, long arg1, long arg2);
__attribute__((visibility("default"))) __attribute__((used))
id  _NativeLibrary_protocolTrampoline_wrzr3t(id target, void * sel, long arg1, long arg2) {
  return ((_ProtocolTrampoline_26)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1, arg2);
}

typedef struct _NSRange  (^_ProtocolTrampoline_27)(void * sel);
__attribute__((visibility("default"))) __attribute__((used))
struct _NSRange  _NativeLibrary_protocolTrampoline_1mh5vs9(id target, void * sel) {
  return ((_ProtocolTrampoline_27)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel);
}

typedef void  (^_ListenerTrampoline_11)(void * arg0, struct _NSRange arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_11 _NativeLibrary_wrapListenerBlock_xpqfd7(_ListenerTrampoline_11 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, struct _NSRange arg1) {
    objc_retainBlock(block);
    block(arg0, arg1);
  };
}

typedef void  (^_BlockingTrampoline_11)(void * waiter, void * arg0, struct _NSRange arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_11 _NativeLibrary_wrapBlockingBlock_xpqfd7(
    _BlockingTrampoline_11 block, _BlockingTrampoline_11 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(void * arg0, struct _NSRange arg1), {
    objc_retainBlock(block);
    block(nil, arg0, arg1);
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, arg0, arg1);
  });
}

typedef void  (^_ProtocolTrampoline_28)(void * sel, struct _NSRange arg1);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeLibrary_protocolTrampoline_xpqfd7(id target, void * sel, struct _NSRange arg1) {
  return ((_ProtocolTrampoline_28)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1);
}

typedef id  (^_ProtocolTrampoline_29)(void * sel, struct _NSRange arg1);
__attribute__((visibility("default"))) __attribute__((used))
id  _NativeLibrary_protocolTrampoline_xzy3cf(id target, void * sel, struct _NSRange arg1) {
  return ((_ProtocolTrampoline_29)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1);
}

typedef struct _NSRange  (^_ProtocolTrampoline_30)(void * sel, long arg1);
__attribute__((visibility("default"))) __attribute__((used))
struct _NSRange  _NativeLibrary_protocolTrampoline_8h6smj(id target, void * sel, long arg1) {
  return ((_ProtocolTrampoline_30)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1);
}

typedef struct _NSRange  (^_ProtocolTrampoline_31)(void * sel, struct CGPoint arg1);
__attribute__((visibility("default"))) __attribute__((used))
struct _NSRange  _NativeLibrary_protocolTrampoline_1lg7chq(id target, void * sel, struct CGPoint arg1) {
  return ((_ProtocolTrampoline_31)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1);
}

typedef struct CGRect  (^_ProtocolTrampoline_32)(void * sel, struct _NSRange arg1);
__attribute__((visibility("default"))) __attribute__((used))
struct CGRect  _NativeLibrary_protocolTrampoline_ox7a80(id target, void * sel, struct _NSRange arg1) {
  return ((_ProtocolTrampoline_32)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1);
}

typedef long  (^_ProtocolTrampoline_33)(void * sel, long arg1);
__attribute__((visibility("default"))) __attribute__((used))
long  _NativeLibrary_protocolTrampoline_1p78ubn(id target, void * sel, long arg1) {
  return ((_ProtocolTrampoline_33)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1);
}

typedef BOOL  (^_ProtocolTrampoline_34)(void * sel, struct objc_selector * arg1);
__attribute__((visibility("default"))) __attribute__((used))
BOOL  _NativeLibrary_protocolTrampoline_w1e3k0(id target, void * sel, struct objc_selector * arg1) {
  return ((_ProtocolTrampoline_34)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1);
}

typedef void  (^_ListenerTrampoline_12)(WKNavigationActionPolicy arg0);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_12 _NativeLibrary_wrapListenerBlock_108000h(_ListenerTrampoline_12 block) NS_RETURNS_RETAINED {
  return ^void(WKNavigationActionPolicy arg0) {
    objc_retainBlock(block);
    block(arg0);
  };
}

typedef void  (^_BlockingTrampoline_12)(void * waiter, WKNavigationActionPolicy arg0);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_12 _NativeLibrary_wrapBlockingBlock_108000h(
    _BlockingTrampoline_12 block, _BlockingTrampoline_12 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(WKNavigationActionPolicy arg0), {
    objc_retainBlock(block);
    block(nil, arg0);
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, arg0);
  });
}

typedef void  (^_ListenerTrampoline_13)(id arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_13 _NativeLibrary_wrapListenerBlock_pfv6jd(_ListenerTrampoline_13 block) NS_RETURNS_RETAINED {
  return ^void(id arg0, id arg1) {
    objc_retainBlock(block);
    block((__bridge id)(__bridge_retained void*)(arg0), (__bridge id)(__bridge_retained void*)(arg1));
  };
}

typedef void  (^_BlockingTrampoline_13)(void * waiter, id arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_13 _NativeLibrary_wrapBlockingBlock_pfv6jd(
    _BlockingTrampoline_13 block, _BlockingTrampoline_13 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(id arg0, id arg1), {
    objc_retainBlock(block);
    block(nil, (__bridge id)(__bridge_retained void*)(arg0), (__bridge id)(__bridge_retained void*)(arg1));
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, (__bridge id)(__bridge_retained void*)(arg0), (__bridge id)(__bridge_retained void*)(arg1));
  });
}

typedef void  (^_ListenerTrampoline_14)(void * arg0, id arg1, id arg2, id arg3);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_14 _NativeLibrary_wrapListenerBlock_bklti2(_ListenerTrampoline_14 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, id arg3) {
    objc_retainBlock(block);
    block(arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2), objc_retainBlock(arg3));
  };
}

typedef void  (^_BlockingTrampoline_14)(void * waiter, void * arg0, id arg1, id arg2, id arg3);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_14 _NativeLibrary_wrapBlockingBlock_bklti2(
    _BlockingTrampoline_14 block, _BlockingTrampoline_14 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(void * arg0, id arg1, id arg2, id arg3), {
    objc_retainBlock(block);
    block(nil, arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2), objc_retainBlock(arg3));
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2), objc_retainBlock(arg3));
  });
}

typedef void  (^_ProtocolTrampoline_35)(void * sel, id arg1, id arg2, id arg3);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeLibrary_protocolTrampoline_bklti2(id target, void * sel, id arg1, id arg2, id arg3) {
  return ((_ProtocolTrampoline_35)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1, arg2, arg3);
}

typedef void  (^_ListenerTrampoline_15)(WKNavigationActionPolicy arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_15 _NativeLibrary_wrapListenerBlock_d2nojr(_ListenerTrampoline_15 block) NS_RETURNS_RETAINED {
  return ^void(WKNavigationActionPolicy arg0, id arg1) {
    objc_retainBlock(block);
    block(arg0, (__bridge id)(__bridge_retained void*)(arg1));
  };
}

typedef void  (^_BlockingTrampoline_15)(void * waiter, WKNavigationActionPolicy arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_15 _NativeLibrary_wrapBlockingBlock_d2nojr(
    _BlockingTrampoline_15 block, _BlockingTrampoline_15 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(WKNavigationActionPolicy arg0, id arg1), {
    objc_retainBlock(block);
    block(nil, arg0, (__bridge id)(__bridge_retained void*)(arg1));
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, arg0, (__bridge id)(__bridge_retained void*)(arg1));
  });
}

typedef void  (^_ListenerTrampoline_16)(void);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_16 _NativeLibrary_wrapListenerBlock_1pl9qdv(_ListenerTrampoline_16 block) NS_RETURNS_RETAINED {
  return ^void() {
    objc_retainBlock(block);
    block();
  };
}

typedef void  (^_BlockingTrampoline_16)(void * waiter);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_16 _NativeLibrary_wrapBlockingBlock_1pl9qdv(
    _BlockingTrampoline_16 block, _BlockingTrampoline_16 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(), {
    objc_retainBlock(block);
    block(nil);
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter);
  });
}

typedef void  (^_ListenerTrampoline_17)(void * arg0, id arg1, id arg2, id arg3, id arg4);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_17 _NativeLibrary_wrapListenerBlock_xx612k(_ListenerTrampoline_17 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, id arg3, id arg4) {
    objc_retainBlock(block);
    block(arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2), (__bridge id)(__bridge_retained void*)(arg3), objc_retainBlock(arg4));
  };
}

typedef void  (^_BlockingTrampoline_17)(void * waiter, void * arg0, id arg1, id arg2, id arg3, id arg4);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_17 _NativeLibrary_wrapBlockingBlock_xx612k(
    _BlockingTrampoline_17 block, _BlockingTrampoline_17 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(void * arg0, id arg1, id arg2, id arg3, id arg4), {
    objc_retainBlock(block);
    block(nil, arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2), (__bridge id)(__bridge_retained void*)(arg3), objc_retainBlock(arg4));
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2), (__bridge id)(__bridge_retained void*)(arg3), objc_retainBlock(arg4));
  });
}

typedef void  (^_ProtocolTrampoline_36)(void * sel, id arg1, id arg2, id arg3, id arg4);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeLibrary_protocolTrampoline_xx612k(id target, void * sel, id arg1, id arg2, id arg3, id arg4) {
  return ((_ProtocolTrampoline_36)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1, arg2, arg3, arg4);
}

typedef void  (^_ListenerTrampoline_18)(WKNavigationResponsePolicy arg0);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_18 _NativeLibrary_wrapListenerBlock_1a5qge(_ListenerTrampoline_18 block) NS_RETURNS_RETAINED {
  return ^void(WKNavigationResponsePolicy arg0) {
    objc_retainBlock(block);
    block(arg0);
  };
}

typedef void  (^_BlockingTrampoline_18)(void * waiter, WKNavigationResponsePolicy arg0);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_18 _NativeLibrary_wrapBlockingBlock_1a5qge(
    _BlockingTrampoline_18 block, _BlockingTrampoline_18 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(WKNavigationResponsePolicy arg0), {
    objc_retainBlock(block);
    block(nil, arg0);
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, arg0);
  });
}

typedef void  (^_ListenerTrampoline_19)(void * arg0, id arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_19 _NativeLibrary_wrapListenerBlock_fjrv01(_ListenerTrampoline_19 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2) {
    objc_retainBlock(block);
    block(arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2));
  };
}

typedef void  (^_BlockingTrampoline_19)(void * waiter, void * arg0, id arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_19 _NativeLibrary_wrapBlockingBlock_fjrv01(
    _BlockingTrampoline_19 block, _BlockingTrampoline_19 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(void * arg0, id arg1, id arg2), {
    objc_retainBlock(block);
    block(nil, arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2));
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2));
  });
}

typedef void  (^_ProtocolTrampoline_37)(void * sel, id arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeLibrary_protocolTrampoline_fjrv01(id target, void * sel, id arg1, id arg2) {
  return ((_ProtocolTrampoline_37)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1, arg2);
}

typedef void  (^_ListenerTrampoline_20)(void * arg0, id arg1, id arg2, id arg3);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_20 _NativeLibrary_wrapListenerBlock_1tz5yf(_ListenerTrampoline_20 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, id arg3) {
    objc_retainBlock(block);
    block(arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2), (__bridge id)(__bridge_retained void*)(arg3));
  };
}

typedef void  (^_BlockingTrampoline_20)(void * waiter, void * arg0, id arg1, id arg2, id arg3);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_20 _NativeLibrary_wrapBlockingBlock_1tz5yf(
    _BlockingTrampoline_20 block, _BlockingTrampoline_20 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(void * arg0, id arg1, id arg2, id arg3), {
    objc_retainBlock(block);
    block(nil, arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2), (__bridge id)(__bridge_retained void*)(arg3));
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2), (__bridge id)(__bridge_retained void*)(arg3));
  });
}

typedef void  (^_ProtocolTrampoline_38)(void * sel, id arg1, id arg2, id arg3);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeLibrary_protocolTrampoline_1tz5yf(id target, void * sel, id arg1, id arg2, id arg3) {
  return ((_ProtocolTrampoline_38)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1, arg2, arg3);
}

typedef void  (^_ListenerTrampoline_21)(NSURLSessionAuthChallengeDisposition arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_21 _NativeLibrary_wrapListenerBlock_n8yd09(_ListenerTrampoline_21 block) NS_RETURNS_RETAINED {
  return ^void(NSURLSessionAuthChallengeDisposition arg0, id arg1) {
    objc_retainBlock(block);
    block(arg0, (__bridge id)(__bridge_retained void*)(arg1));
  };
}

typedef void  (^_BlockingTrampoline_21)(void * waiter, NSURLSessionAuthChallengeDisposition arg0, id arg1);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_21 _NativeLibrary_wrapBlockingBlock_n8yd09(
    _BlockingTrampoline_21 block, _BlockingTrampoline_21 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(NSURLSessionAuthChallengeDisposition arg0, id arg1), {
    objc_retainBlock(block);
    block(nil, arg0, (__bridge id)(__bridge_retained void*)(arg1));
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, arg0, (__bridge id)(__bridge_retained void*)(arg1));
  });
}

typedef void  (^_ListenerTrampoline_22)(BOOL arg0);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_22 _NativeLibrary_wrapListenerBlock_1s56lr9(_ListenerTrampoline_22 block) NS_RETURNS_RETAINED {
  return ^void(BOOL arg0) {
    objc_retainBlock(block);
    block(arg0);
  };
}

typedef void  (^_BlockingTrampoline_22)(void * waiter, BOOL arg0);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_22 _NativeLibrary_wrapBlockingBlock_1s56lr9(
    _BlockingTrampoline_22 block, _BlockingTrampoline_22 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(BOOL arg0), {
    objc_retainBlock(block);
    block(nil, arg0);
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, arg0);
  });
}

typedef void  (^_ListenerTrampoline_23)(void * arg0, id arg1, id arg2, BOOL arg3, id arg4);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_23 _NativeLibrary_wrapListenerBlock_axwdf6(_ListenerTrampoline_23 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, id arg1, id arg2, BOOL arg3, id arg4) {
    objc_retainBlock(block);
    block(arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2), arg3, objc_retainBlock(arg4));
  };
}

typedef void  (^_BlockingTrampoline_23)(void * waiter, void * arg0, id arg1, id arg2, BOOL arg3, id arg4);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_23 _NativeLibrary_wrapBlockingBlock_axwdf6(
    _BlockingTrampoline_23 block, _BlockingTrampoline_23 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(void * arg0, id arg1, id arg2, BOOL arg3, id arg4), {
    objc_retainBlock(block);
    block(nil, arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2), arg3, objc_retainBlock(arg4));
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, arg0, (__bridge id)(__bridge_retained void*)(arg1), (__bridge id)(__bridge_retained void*)(arg2), arg3, objc_retainBlock(arg4));
  });
}

typedef void  (^_ProtocolTrampoline_39)(void * sel, id arg1, id arg2, BOOL arg3, id arg4);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeLibrary_protocolTrampoline_axwdf6(id target, void * sel, id arg1, id arg2, BOOL arg3, id arg4) {
  return ((_ProtocolTrampoline_39)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1, arg2, arg3, arg4);
}

Protocol* _NativeLibrary_WKNavigationDelegate(void) { return @protocol(WKNavigationDelegate); }

typedef void  (^_ListenerTrampoline_24)(WKMediaPlaybackState arg0);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_24 _NativeLibrary_wrapListenerBlock_19s8ne9(_ListenerTrampoline_24 block) NS_RETURNS_RETAINED {
  return ^void(WKMediaPlaybackState arg0) {
    objc_retainBlock(block);
    block(arg0);
  };
}

typedef void  (^_BlockingTrampoline_24)(void * waiter, WKMediaPlaybackState arg0);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_24 _NativeLibrary_wrapBlockingBlock_19s8ne9(
    _BlockingTrampoline_24 block, _BlockingTrampoline_24 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(WKMediaPlaybackState arg0), {
    objc_retainBlock(block);
    block(nil, arg0);
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, arg0);
  });
}

typedef void  (^_ListenerTrampoline_25)(id arg0);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_25 _NativeLibrary_wrapListenerBlock_xtuoz7(_ListenerTrampoline_25 block) NS_RETURNS_RETAINED {
  return ^void(id arg0) {
    objc_retainBlock(block);
    block((__bridge id)(__bridge_retained void*)(arg0));
  };
}

typedef void  (^_BlockingTrampoline_25)(void * waiter, id arg0);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_25 _NativeLibrary_wrapBlockingBlock_xtuoz7(
    _BlockingTrampoline_25 block, _BlockingTrampoline_25 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(id arg0), {
    objc_retainBlock(block);
    block(nil, (__bridge id)(__bridge_retained void*)(arg0));
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, (__bridge id)(__bridge_retained void*)(arg0));
  });
}

typedef id  (^_ProtocolTrampoline_40)(void * sel, unsigned long arg1, struct _NSRange * arg2, BOOL * arg3);
__attribute__((visibility("default"))) __attribute__((used))
id  _NativeLibrary_protocolTrampoline_19qfjta(id target, void * sel, unsigned long arg1, struct _NSRange * arg2, BOOL * arg3) {
  return ((_ProtocolTrampoline_40)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1, arg2, arg3);
}

typedef unsigned long  (^_ProtocolTrampoline_41)(void * sel);
__attribute__((visibility("default"))) __attribute__((used))
unsigned long  _NativeLibrary_protocolTrampoline_1ckyi24(id target, void * sel) {
  return ((_ProtocolTrampoline_41)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel);
}

typedef BOOL  (^_ProtocolTrampoline_42)(void * sel, id arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
BOOL  _NativeLibrary_protocolTrampoline_2n06mv(id target, void * sel, id arg1, id arg2) {
  return ((_ProtocolTrampoline_42)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1, arg2);
}

typedef void  (^_ListenerTrampoline_26)(void * arg0, struct _NSRange arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_26 _NativeLibrary_wrapListenerBlock_1f6txb5(_ListenerTrampoline_26 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0, struct _NSRange arg1, id arg2) {
    objc_retainBlock(block);
    block(arg0, arg1, (__bridge id)(__bridge_retained void*)(arg2));
  };
}

typedef void  (^_BlockingTrampoline_26)(void * waiter, void * arg0, struct _NSRange arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_26 _NativeLibrary_wrapBlockingBlock_1f6txb5(
    _BlockingTrampoline_26 block, _BlockingTrampoline_26 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(void * arg0, struct _NSRange arg1, id arg2), {
    objc_retainBlock(block);
    block(nil, arg0, arg1, (__bridge id)(__bridge_retained void*)(arg2));
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, arg0, arg1, (__bridge id)(__bridge_retained void*)(arg2));
  });
}

typedef void  (^_ProtocolTrampoline_43)(void * sel, struct _NSRange arg1, id arg2);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeLibrary_protocolTrampoline_1f6txb5(id target, void * sel, struct _NSRange arg1, id arg2) {
  return ((_ProtocolTrampoline_43)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1, arg2);
}

typedef void  (^_ListenerTrampoline_27)(void * arg0);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_27 _NativeLibrary_wrapListenerBlock_ovsamd(_ListenerTrampoline_27 block) NS_RETURNS_RETAINED {
  return ^void(void * arg0) {
    objc_retainBlock(block);
    block(arg0);
  };
}

typedef void  (^_BlockingTrampoline_27)(void * waiter, void * arg0);
__attribute__((visibility("default"))) __attribute__((used))
_ListenerTrampoline_27 _NativeLibrary_wrapBlockingBlock_ovsamd(
    _BlockingTrampoline_27 block, _BlockingTrampoline_27 listenerBlock,
    DOBJC_Context* ctx) NS_RETURNS_RETAINED {
  BLOCKING_BLOCK_IMPL(ctx, ^void(void * arg0), {
    objc_retainBlock(block);
    block(nil, arg0);
  }, {
    objc_retainBlock(listenerBlock);
    listenerBlock(waiter, arg0);
  });
}

typedef void  (^_ProtocolTrampoline_44)(void * sel);
__attribute__((visibility("default"))) __attribute__((used))
void  _NativeLibrary_protocolTrampoline_ovsamd(id target, void * sel) {
  return ((_ProtocolTrampoline_44)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel);
}

typedef id  (^_ProtocolTrampoline_45)(void * sel, unsigned long arg1, struct _NSRange * arg2);
__attribute__((visibility("default"))) __attribute__((used))
id  _NativeLibrary_protocolTrampoline_vt1y0w(id target, void * sel, unsigned long arg1, struct _NSRange * arg2) {
  return ((_ProtocolTrampoline_45)((id (*)(id, SEL, SEL))objc_msgSend)(target, @selector(getDOBJCDartProtocolMethodForSelector:), sel))(sel, arg1, arg2);
}
#undef BLOCKING_BLOCK_IMPL

#pragma clang diagnostic pop
