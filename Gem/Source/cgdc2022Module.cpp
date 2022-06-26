
#include <AzCore/Memory/SystemAllocator.h>
#include <AzCore/Module/Module.h>

#include "cgdc2022SystemComponent.h"

namespace cgdc2022
{
    class cgdc2022Module
        : public AZ::Module
    {
    public:
        AZ_RTTI(cgdc2022Module, "{1AFD3F5C-F6EB-47A6-96AF-0B12FD27C1CE}", AZ::Module);
        AZ_CLASS_ALLOCATOR(cgdc2022Module, AZ::SystemAllocator, 0);

        cgdc2022Module()
            : AZ::Module()
        {
            // Push results of [MyComponent]::CreateDescriptor() into m_descriptors here.
            m_descriptors.insert(m_descriptors.end(), {
                cgdc2022SystemComponent::CreateDescriptor(),
            });
        }

        /**
         * Add required SystemComponents to the SystemEntity.
         */
        AZ::ComponentTypeList GetRequiredSystemComponents() const override
        {
            return AZ::ComponentTypeList{
                azrtti_typeid<cgdc2022SystemComponent>(),
            };
        }
    };
}// namespace cgdc2022

AZ_DECLARE_MODULE_CLASS(Gem_cgdc2022, cgdc2022::cgdc2022Module)
