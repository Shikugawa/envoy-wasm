use lazy_static::lazy_static;
use std::collections::HashMap;
use std::sync::Mutex;

pub trait RootContext {}
pub trait Context {}
pub trait RootContextFactory {
  fn create(&self) -> Box<dyn Sync + RootContext>;
}
pub trait ContextFactory {
  fn create(&self) -> Box<dyn Sync + Context>;
}

struct RootContextFactoryStore {
  hangar: HashMap<u32, &'static (dyn RootContextFactory + Sync)>,
}

impl RootContextFactoryStore {
  fn new() -> RootContextFactoryStore {
    RootContextFactoryStore {
      hangar: HashMap::new(),
    }
  }

  fn add<U: RootContextFactory + Sync>(&mut self, factory: &'static U) {
    self.hangar.insert(1, factory);
  }

  fn get(&self, id: u32) -> Option<&&(dyn RootContextFactory + Sync)> {
    self.hangar.get(&id)
  }
}

struct ContextFactoryStore {
  hangar: HashMap<u32, &'static (dyn ContextFactory + Sync)>,
}

impl ContextFactoryStore {
  fn new() -> ContextFactoryStore {
    ContextFactoryStore {
      hangar: HashMap::new(),
    }
  }

  fn add<U: ContextFactory + Sync>(&mut self, factory: &'static U) {
    self.hangar.insert(1, factory);
  }

  fn get(&self, id: u32) -> Option<&&(dyn ContextFactory + Sync)> {
    self.hangar.get(&id)
  }
}

lazy_static! {
  static ref ROOT_CONTEXT_FACTORY_STORE: Mutex<RootContextFactoryStore> =
    Mutex::new(RootContextFactoryStore::new());
  static ref CONTEXT_FACTORY_STORE: Mutex<ContextFactoryStore> =
    Mutex::new(ContextFactoryStore::new());
}

pub struct Registered {}

pub fn register_factory<T: RootContextFactory + Sync, U: ContextFactory + Sync>(
  _rcf: &'static T,
  _cf: &'static U,
) -> Registered {
  ROOT_CONTEXT_FACTORY_STORE.lock().unwrap().add(_rcf);
  CONTEXT_FACTORY_STORE.lock().unwrap().add(_cf);
  Registered {}
}

pub fn ensure_root_context() -> Box<Sync + RootContext> {
  match ROOT_CONTEXT_FACTORY_STORE.lock().unwrap().get(1) {
    None => panic!("failed to find root context factory!"),
    Some(store) => store.create(),
  }
}

pub fn ensure_context() -> Box<Sync + Context> {
  match CONTEXT_FACTORY_STORE.lock().unwrap().get(1) {
    None => panic!("failed to find root context factory!"),
    Some(store) => store.create(),
  }
}
