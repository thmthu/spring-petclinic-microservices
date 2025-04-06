package org.springframework.samples.petclinic.customers.web;

import org.springframework.samples.petclinic.customers.model.Owner;
import org.springframework.samples.petclinic.customers.model.Pet;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;

class OwnerTest {

    @Test
    void testGettersAndSetters() {
        Owner owner = new Owner();
        owner.setFirstName("John");
        owner.setLastName("Doe");
        owner.setAddress("123 Main St");
        owner.setCity("Springfield");
        owner.setTelephone("1234567890");

        assertEquals("John", owner.getFirstName());
        assertEquals("Doe", owner.getLastName());
        assertEquals("123 Main St", owner.getAddress());
        assertEquals("Springfield", owner.getCity());
        assertEquals("1234567890", owner.getTelephone());
    }

    @Test
    void testAddPet() {
        Owner owner = new Owner();
        Pet pet = new Pet();
        pet.setName("Buddy");

        owner.addPet(pet);

        List<Pet> pets = owner.getPets();
        assertEquals(1, pets.size());
        assertEquals("Buddy", pets.get(0).getName());
        assertEquals(owner, pets.get(0).getOwner());
    }

    @Test
    void testGetPets() {
        Owner owner = new Owner();
        assertNotNull(owner.getPets());
        assertTrue(owner.getPets().isEmpty());

        Pet pet = new Pet();
        pet.setName("Buddy");
        owner.addPet(pet);

        List<Pet> pets = owner.getPets();
        assertEquals(1, pets.size());
        assertEquals("Buddy", pets.get(0).getName());
    }

    @Test
    void testToString() {
        Owner owner = new Owner();
        owner.setFirstName("John");
        owner.setLastName("Doe");
        owner.setAddress("123 Main St");
        owner.setCity("Springfield");
        owner.setTelephone("1234567890");

        String toString = owner.toString();
        assertTrue(toString.contains("firstName = 'John'"));
        assertTrue(toString.contains("lastName = 'Doe'"));
        assertTrue(toString.contains("address = '123 Main St'"));
        assertTrue(toString.contains("city = 'Springfield'"));
        assertTrue(toString.contains("telephone = '1234567890'"));
    }

        @Test
    void testGetPetsInternal_WhenPetsIsNull_ShouldInitializePets() throws Exception {
        Owner owner = new Owner();

        var method = Owner.class.getDeclaredMethod("getPetsInternal");
        method.setAccessible(true);

        @SuppressWarnings("unchecked")
        Set<Pet> pets = (Set<Pet>) method.invoke(owner);
        assertNotNull(pets);
        assertTrue(pets.isEmpty());
    }

    @Test
    void testGetPetsInternal_WhenPetsIsNotNull_ShouldReturnExistingPets() throws Exception {
        Owner owner = new Owner();

        var method = Owner.class.getDeclaredMethod("getPetsInternal");
        method.setAccessible(true);

        @SuppressWarnings("unchecked")
        Set<Pet> pets = (Set<Pet>) method.invoke(owner);
        Pet pet = new Pet();
        pets.add(pet);

        @SuppressWarnings("unchecked")
        Set<Pet> result = (Set<Pet>) method.invoke(owner);
        assertEquals(1, result.size());
        assertTrue(result.contains(pet));
    }
}