
#[starknet::interface]
trait ICounter<TContractState> {
    fn get_counter(self: @TContractState) -> u32;
    fn increase_counter(ref self: TContractState);
}

#[starknet::contract]
mod Counter {
    use openzeppelin::access::ownable::ownable::OwnableComponent::InternalTrait;
    use starknet::ContractAddress;
    use kill_switch::IKillSwitchDispatcherTrait;
    use kill_switch::IKillSwitchDispatcher;
    use openzeppelin::access::ownable::OwnableComponent;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;

    #[storage]
    struct Storage {
        counter: u32,
        kill_switch: IKillSwitchDispatcher,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[constructor]
    fn constructor(ref self: ContractState, input: u32, kill_switch_address: ContractAddress, initial_owner: ContractAddress){
        self.counter.write(input);
        self.kill_switch.write(IKillSwitchDispatcher { contract_address: kill_switch_address });
        self.ownable.initializer(initial_owner);
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        CounterIncreased: CounterIncreased,
        OwnableEvent: OwnableComponent::Event
    }

    #[derive(Drop, starknet::Event)]
    struct CounterIncreased {
        #[key]
        counter: u32
    }

    #[abi(embed_v0)]
    impl ICounterImpl of super::ICounter<ContractState> {
        
        fn get_counter(self: @ContractState) -> u32 {
            self.counter.read()
        }

        fn increase_counter(ref self: ContractState) {
            self.ownable.assert_only_owner();

            let switch_active = self.kill_switch.read().is_active();

            assert!(!switch_active,"Kill Switch is active");
            
            if !switch_active {
                let new_value = self.counter.read() + 1;
                self.counter.write(new_value);
                self.emit(CounterIncreased{counter: new_value});
            }   
          
        }

    }
}
